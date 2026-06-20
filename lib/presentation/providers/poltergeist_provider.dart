import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/device_id_service.dart';
import '../../domain/entities/connection_config.dart';
import '../../domain/entities/gui_action.dart';
import '../../domain/entities/session_state.dart';

/// Decodes a base64 screenshot. Top-level so it can run in a background
/// isolate via [compute], keeping the heavy decode off the UI thread.
Uint8List _decodeBase64(String b64) => base64Decode(b64);

// ── State ─────────────────────────────────────────────────────────────────────

class PoltergeistState {
  final List<GuiAction> catalog;
  final List<VoiceProfile> voices;
  final List<String> presets;
  final bool isExecuting;
  final String? lastActionId;
  final bool? lastSuccess;
  final String? lastOutput;
  final Uint8List? screenshotBytes; // decoded JPEG/PNG
  final int screenW; // original host screen width (from screenshot output)
  final int screenH;
  final int screenshotSeq; // bumps each time a fresh screenshot arrives
  final SessionStatus connectionStatus;
  final String? errorMessage;

  const PoltergeistState({
    this.catalog = const [],
    this.voices = const [],
    this.presets = const [],
    this.isExecuting = false,
    this.lastActionId,
    this.lastSuccess,
    this.lastOutput,
    this.screenshotBytes,
    this.screenW = 0,
    this.screenH = 0,
    this.screenshotSeq = 0,
    this.connectionStatus = SessionStatus.disconnected,
    this.errorMessage,
  });

  PoltergeistState copyWith({
    List<GuiAction>? catalog,
    List<VoiceProfile>? voices,
    List<String>? presets,
    bool? isExecuting,
    String? lastActionId,
    bool? lastSuccess,
    String? lastOutput,
    Uint8List? screenshotBytes,
    int? screenW,
    int? screenH,
    int? screenshotSeq,
    SessionStatus? connectionStatus,
    String? errorMessage,
  }) =>
      PoltergeistState(
        catalog: catalog ?? this.catalog,
        voices: voices ?? this.voices,
        presets: presets ?? this.presets,
        isExecuting: isExecuting ?? this.isExecuting,
        lastActionId: lastActionId ?? this.lastActionId,
        lastSuccess: lastSuccess ?? this.lastSuccess,
        lastOutput: lastOutput ?? this.lastOutput,
        screenshotBytes: screenshotBytes ?? this.screenshotBytes,
        screenW: screenW ?? this.screenW,
        screenH: screenH ?? this.screenH,
        screenshotSeq: screenshotSeq ?? this.screenshotSeq,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        errorMessage: errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PoltergeistNotifier extends StateNotifier<PoltergeistState> {
  PoltergeistNotifier() : super(const PoltergeistState());

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  final _rng = Random();

  ConnectionConfig? _config;
  String? _wsUrl;
  String? _token;
  bool _shouldReconnect = false;
  int _attempts = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> connectWithConfig(ConnectionConfig config) async {
    if (state.connectionStatus.isConnecting ||
        state.connectionStatus.isConnected) {
      return;
    }

    _config = config;
    _wsUrl = '${config.wsUrl}${AppConstants.wsPoltergeistPath}';
    _shouldReconnect = true;
    _attempts = 0;
    state = state.copyWith(
        connectionStatus: SessionStatus.connecting, errorMessage: null);

    try {
      _token = await _authenticate(config);
      await _doConnect();
    } catch (e) {
      state = state.copyWith(
        connectionStatus: SessionStatus.error,
        errorMessage: e.toString(),
      );
      _scheduleReconnect();
    }
  }

  /// Called on app resume — reconnect immediately if the background drop
  /// killed the socket. Re-authenticates (token may have expired).
  void onResume() {
    final cfg = _config;
    if (cfg == null) return;
    if (state.connectionStatus.isConnected ||
        state.connectionStatus.isConnecting) {
      return;
    }
    _reconnectTimer?.cancel();
    _attempts = 0;
    connectWithConfig(cfg);
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    state = state.copyWith(
      connectionStatus: SessionStatus.disconnected,
      errorMessage: null,
    );
  }

  /// Sends an action. [params] carries arbitrary fields (text, x, y, dy,
  /// preset, rate...). Interactive actions (mouse_/kb_) bypass the busy-guard
  /// so rapid sniper-mode taps are never dropped; heavy actions are gated to
  /// avoid the duplicate sends that previously tripped the 429 limit.
  void executeAction(String actionId, {Map<String, dynamic>? params}) {
    if (!state.connectionStatus.isConnected) return;
    final interactive =
        actionId.startsWith('mouse_') || actionId.startsWith('kb_');
    if (!interactive && state.isExecuting) return; // busy-guard

    state = state.copyWith(isExecuting: true, lastActionId: actionId);
    final msg = <String, dynamic>{
      'type': 'execute_action',
      'actionId': actionId,
    };
    if (params != null && params.isNotEmpty) {
      msg['params'] = params.map((k, v) => MapEntry(k, '$v'));
    }
    _send(msg);
  }

  void requestVoices() {
    if (!state.connectionStatus.isConnected) return;
    _send({'type': 'get_voices'});
  }

  void clearLastResult() {
    state = state.copyWith(
      lastActionId: null,
      lastSuccess: null,
      lastOutput: null,
    );
  }

  // ── WebSocket internals ────────────────────────────────────────────────────

  Future<void> _doConnect() async {
    if (!_shouldReconnect || _token == null) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl!));
      await _channel!.ready.timeout(AppConstants.connectTimeout);

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _send({'type': 'auth', 'token': _token!});
      _startPing();
      _attempts = 0;
    } catch (e) {
      _onError(e);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'authenticated':
          state = state.copyWith(connectionStatus: SessionStatus.connected);
          _applyCatalog(data['catalog'] as List?);
          requestVoices(); // pull the host voice list once connected

        case 'catalog':
          _applyCatalog(data['actions'] as List?);

        case 'voices':
          final rawVoices = data['voices'] as List?;
          final rawPresets = data['presets'] as List?;
          state = state.copyWith(
            voices: rawVoices == null
                ? const []
                : rawVoices
                    .cast<Map<String, dynamic>>()
                    .map(VoiceProfile.fromJson)
                    .toList(),
            presets: rawPresets == null
                ? const []
                : rawPresets.map((e) => '$e').toList(),
          );

        case 'action_result':
          _onActionResult(data);

        case 'error':
          state = state.copyWith(
            isExecuting: false,
            errorMessage: data['message'] as String?,
          );

        case 'pong':
          break;
      }
    } catch (_) {}
  }

  void _applyCatalog(List? raw) {
    if (raw == null) return;
    state = state.copyWith(
      catalog:
          raw.cast<Map<String, dynamic>>().map(GuiAction.fromJson).toList(),
    );
  }

  Future<void> _onActionResult(Map<String, dynamic> data) async {
    final actionId = data['actionId'] as String?;
    final success = data['success'] as bool?;
    final output = data['output'] as String?;
    final b64 = data['data'] as String?;

    state = state.copyWith(
      isExecuting: false,
      lastActionId: actionId,
      lastSuccess: success,
      lastOutput: output,
    );

    // Screenshot payload: decode off the UI thread, parse original dims.
    if (b64 != null && b64.isNotEmpty) {
      final bytes = await compute(_decodeBase64, b64);
      final dims = _parseDims(output);
      state = state.copyWith(
        screenshotBytes: bytes,
        screenW: dims.$1,
        screenH: dims.$2,
        screenshotSeq: state.screenshotSeq + 1,
      );
    }
  }

  (int, int) _parseDims(String? output) {
    if (output == null) return (state.screenW, state.screenH);
    final m = RegExp(r'(\d+)x(\d+)').firstMatch(output);
    if (m == null) return (state.screenW, state.screenH);
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  void _onError(dynamic error) {
    state = state.copyWith(
      connectionStatus: SessionStatus.error,
      errorMessage: error.toString(),
    );
    _cleanup();
    _scheduleReconnect();
  }

  void _onDone() {
    if (state.connectionStatus == SessionStatus.disconnected) return;
    state = state.copyWith(connectionStatus: SessionStatus.disconnected);
    _cleanup();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _config == null) return;
    _attempts++;
    final Duration delay;
    if (_attempts == 1) {
      delay = Duration.zero;
    } else {
      final base = (2.0 * pow(2.0, _attempts - 2)).clamp(2.0, 15.0);
      final jitter = base * 0.25 * (_rng.nextDouble() * 2 - 1);
      final ms = ((base + jitter) * 1000).round().clamp(500, 15000);
      delay = Duration(milliseconds: ms);
    }
    _reconnectTimer = Timer(delay, () async {
      if (!_shouldReconnect || _config == null) return;
      try {
        _token = await _authenticate(_config!);
        await _doConnect();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) {
      if (state.connectionStatus.isConnected) _send({'type': 'ping'});
    });
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  @override
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    super.dispose();
  }
}

// ── Auth (same flow as terminal_provider) ─────────────────────────────────────

Future<String> _authenticate(ConnectionConfig config) async {
  final deviceId = await DeviceIdService.get();
  final url = Uri.parse('${config.httpUrl}${AppConstants.loginPath}');
  final response = await http
      .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': config.password, 'deviceId': deviceId}),
      )
      .timeout(AppConstants.requestTimeout);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) throw Exception('Token vacío');
    return token;
  } else if (response.statusCode == 401) {
    throw Exception('Credenciales incorrectas o dispositivo no autorizado');
  } else if (response.statusCode == 429) {
    throw Exception('Demasiados intentos. Espera 15 minutos.');
  }
  throw Exception('Error del servidor: ${response.statusCode}');
}

// ── Provider ──────────────────────────────────────────────────────────────────

final poltergeistProvider =
    StateNotifierProvider<PoltergeistNotifier, PoltergeistState>(
  (ref) => PoltergeistNotifier(),
);
