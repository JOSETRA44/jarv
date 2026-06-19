import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';
import '../../domain/entities/connection_config.dart';
import 'i_transport_strategy.dart';
// AppConstants.wsMobilePath = '/ws/mobile' must be appended to the base WS URL.

/// WebSocket-based transport strategy.
///
/// Implements ITransportStrategy over a persistent WebSocket connection with:
/// - JWT authentication on connect
/// - Exponential backoff reconnect (2s → 30s)
/// - 30-second keepalive ping
///
/// Replaces the old JarvisWsDatasource with a clean strategy interface.
class WebSocketTransport implements ITransportStrategy {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  String? _wsUrl;
  String? _token;
  bool _connected = false;
  bool _shouldReconnect = false;
  int _attempts = 0;

  @override
  Stream<String> get statusStream => _statusController.stream;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(ConnectionConfig config, String token) async {
    // config.wsUrl gives the base (e.g. ws://192.168.0.48:3000).
    // We must append the mobile endpoint path, or the server closes the
    // WebSocket immediately because "/" has no handler.
    _wsUrl = '${config.wsUrl}${AppConstants.wsMobilePath}';
    _token = token;
    _shouldReconnect = true;
    _attempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    _statusController.add('connecting');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl!));
      await _channel!.ready.timeout(AppConstants.connectTimeout);

      _sub = _channel!.stream.listen(
        _onRaw,
        onError: _onError,
        onDone: _onDone,
      );

      _sendRaw({'type': 'auth', 'token': _token!});
      _startPing();
      _attempts = 0;
    } catch (e) {
      _onError(e);
    }
  }

  void _onRaw(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'authenticated') {
        _connected = true;
        _statusController.add('connected');
      }
      if (type == 'pong') return; // filter keepalive noise

      _events.add(data);
    } catch (_) {}
  }

  void _onError(dynamic error) {
    _connected = false;
    _statusController.add('error:${error.toString()}');
    _cleanup();
    _scheduleReconnect();
  }

  void _onDone() {
    _connected = false;
    _statusController.add('disconnected');
    _cleanup();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _attempts++;
    final secs = min(
      AppConstants.reconnectInitialDelay.inSeconds * pow(2, _attempts - 1),
      AppConstants.reconnectMaxDelay.inSeconds.toDouble(),
    );
    _reconnectTimer = Timer(Duration(seconds: secs.toInt()), () {
      if (_shouldReconnect) _doConnect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) {
      if (_connected) _sendRaw({'type': 'ping'});
    });
  }

  void _sendRaw(Map<String, dynamic> data) {
    try { _channel?.sink.add(jsonEncode(data)); } catch (_) {}
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    _sendRaw(message);
  }

  @override
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _connected = false;
    _cleanup();
    _statusController.add('disconnected');
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
  }

  @override
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    _events.close();
    _statusController.close();
  }
}
