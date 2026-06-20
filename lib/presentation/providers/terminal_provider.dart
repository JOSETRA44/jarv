import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:xterm/xterm.dart';
import '../../core/constants/app_constants.dart';
import '../../core/transport/i_transport_strategy.dart';
import '../../core/transport/transport_factory.dart';
import '../../domain/entities/connection_config.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/entities/terminal_block.dart';
import '../../domain/entities/session_tab.dart';
import '../../core/services/device_id_service.dart';

// ── State ────────────────────────────────────────────────────────────────────

class TerminalState {
  final List<TerminalBlock> blocks;
  final List<SessionTab> sessions;
  final String activeSessionId;
  final String currentCwd;
  final SessionStatus connectionStatus;

  const TerminalState({
    this.blocks = const [],
    this.sessions = const [],
    this.activeSessionId = '',
    this.currentCwd = '',
    this.connectionStatus = SessionStatus.disconnected,
  });

  bool get isWaitingForPrompt => blocks.any(
        (b) => b.sessionId == activeSessionId && b.isRunning,
      );

  SessionTab? get activeSession {
    if (activeSessionId.isEmpty) return null;
    final matches = sessions.where((s) => s.id == activeSessionId);
    return matches.isEmpty ? null : matches.first;
  }

  TerminalState copyWith({
    List<TerminalBlock>? blocks,
    List<SessionTab>? sessions,
    String? activeSessionId,
    String? currentCwd,
    SessionStatus? connectionStatus,
  }) {
    return TerminalState(
      blocks: blocks ?? this.blocks,
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      currentCwd: currentCwd ?? this.currentCwd,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class TerminalNotifier extends StateNotifier<TerminalState> {
  ITransportStrategy _transport;
  StreamSubscription? _eventSub;
  StreamSubscription? _statusSub;
  Timer? _autoRetryTimer;
  ConnectionConfig? _config;

  // One xterm Terminal per session — handles all VT100 rendering for running blocks.
  final Map<String, Terminal> _terminals = {};

  TerminalNotifier(this._transport) : super(const TerminalState()) {
    _subscribe();
  }

  void _subscribe() {
    _eventSub?.cancel();
    _statusSub?.cancel();
    _eventSub = _transport.events.listen(_handleEvent);
    _statusSub = _transport.statusStream.listen(_handleStatus);
  }

  // ── Transport status ──────────────────────────────────────────────────────

  void _handleStatus(String status) {
    if (status == 'disconnected') {
      state = state.copyWith(connectionStatus: SessionStatus.disconnected);
    } else if (status.startsWith('error:')) {
      state = state.copyWith(connectionStatus: SessionStatus.error);
    }
  }

  // ── Protocol event dispatch ───────────────────────────────────────────────

  void _handleEvent(Map<String, dynamic> data) {
    switch (data['type'] as String?) {
      case 'authenticated':
        _onAuthenticated(data);
      case 'session_created':
        _onSessionCreated(data);
      case 'session_closed':
        _onSessionClosed(data);
      case 'raw':
        _onRaw(data);
      case 'output':
        _onOutput(data);
      case 'clear_output':
        _onClearOutput(data);
      case 'prompt':
        _onPrompt(data);
      case 'error':
        _onServerError(data);
    }
  }

  void _onAuthenticated(Map<String, dynamic> data) {
    final connId = data['connectionId'] as String? ?? '';
    final rawSessions = (data['sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final tabs = rawSessions.map((s) => SessionTab(
          id: s['id'] as String? ?? '',
          cwd: s['cwd'] as String? ?? '',
          isActive: false,
        )).toList();

    final activeId = tabs.isNotEmpty ? tabs.first.id : '';
    final activeCwd = tabs.isNotEmpty ? tabs.first.cwd : '';

    final updatedTabs = tabs
        .map((t) => t.copyWith(isActive: t.id == activeId))
        .toList();

    final motd = TerminalBlock.motd(
      cwd: activeCwd,
      connectionId: connId,
      sessionId: activeId,
    );

    final trimmedBlocks = _trim([...state.blocks, motd]);

    state = state.copyWith(
      connectionStatus: SessionStatus.connected,
      sessions: updatedTabs,
      activeSessionId: activeId,
      currentCwd: activeCwd,
      blocks: trimmedBlocks,
    );
    _autoRetryTimer?.cancel();
  }

  void _onSessionCreated(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final cwd = data['cwd'] as String? ?? '';
    if (id.isEmpty) return;
    final tab = SessionTab(id: id, cwd: cwd, isActive: false);
    state = state.copyWith(sessions: [...state.sessions, tab]);
  }

  void _onSessionClosed(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    _terminals.remove(id);
    final remaining = state.sessions.where((s) => s.id != id).toList();
    String newActive = state.activeSessionId;
    if (newActive == id && remaining.isNotEmpty) {
      newActive = remaining.last.id;
      remaining[remaining.length - 1] =
          remaining.last.copyWith(isActive: true);
    }
    state = state.copyWith(sessions: remaining, activeSessionId: newActive);
  }

  // ── xterm Terminal management ─────────────────────────────────────────────

  Terminal _getOrCreateTerminal(String sessionId) {
    if (_terminals.containsKey(sessionId)) return _terminals[sessionId]!;
    final t = Terminal(maxLines: 5000);
    // onResize fires when TerminalView (autoResize=true) resizes the terminal.
    // Forward the new dimensions to the backend PTY.
    t.onResize = (cols, rows, _, __) => resizePty(cols, rows, sessionId: sessionId);
    _terminals[sessionId] = t;
    return t;
  }

  /// Expose the Terminal for a session so widgets can bind TerminalView to it.
  Terminal? getTerminal(String sessionId) => _terminals[sessionId];

  void _onRaw(Map<String, dynamic> data) {
    final rawData = data['data'] as String? ?? '';
    final sessionId = data['session'] as String? ?? state.activeSessionId;
    if (rawData.isEmpty) return;
    _getOrCreateTerminal(sessionId).write(rawData);
  }

  void _onOutput(Map<String, dynamic> data) {
    final text = data['data'] as String? ?? '';
    // replace > 0: remove that many trailing lines before appending.
    // This handles \r (carriage-return) overwrites from spinner/progress-bar
    // output — the backend tells us how many lines were overwritten.
    final replaceLast = (data['replace'] as int?) ?? 0;
    final sessionId = data['session'] as String? ?? state.activeSessionId;
    if (text.isEmpty) return;

    final incoming = text.split('\n').where((l) => l.isNotEmpty).toList();
    if (incoming.isEmpty) return;

    final blocks = List<TerminalBlock>.from(state.blocks);
    final idx = _lastRunningBlock(blocks, sessionId);
    if (idx >= 0) {
      var existing = List<String>.from(blocks[idx].outputLines);
      if (replaceLast > 0 && existing.isNotEmpty) {
        final trim = replaceLast.clamp(0, existing.length);
        existing = existing.sublist(0, existing.length - trim);
      }
      blocks[idx] = blocks[idx].copyWith(
        outputLines: [...existing, ...incoming],
      );
      state = state.copyWith(blocks: blocks);
    }
  }

  // Emitted when the TUI sends a screen-clear sequence (\x1b[2J etc.).
  // Wipe the running block's output so the next redraw starts fresh instead
  // of visually stacking over old lines.
  void _onClearOutput(Map<String, dynamic> data) {
    final sessionId = data['session'] as String? ?? state.activeSessionId;
    final blocks = List<TerminalBlock>.from(state.blocks);
    final idx = _lastRunningBlock(blocks, sessionId);
    if (idx >= 0) {
      blocks[idx] = blocks[idx].copyWith(outputLines: []);
      state = state.copyWith(blocks: blocks);
    }
  }

  void _onPrompt(Map<String, dynamic> data) {
    final cwd = data['cwd'] as String? ?? '';
    final exitCode = data['exitCode'] as int? ?? 0;
    final sessionId = data['session'] as String? ?? state.activeSessionId;

    final blocks = List<TerminalBlock>.from(state.blocks);
    final idx = _lastRunningBlock(blocks, sessionId);
    if (idx >= 0) {
      final b = blocks[idx];
      blocks[idx] = b.copyWith(
        isComplete: true,
        exitCode: exitCode,
        duration: DateTime.now().difference(b.startedAt),
      );
    }

    final sessions = state.sessions.map((s) {
      if (s.id == sessionId && cwd.isNotEmpty) return s.copyWith(cwd: cwd);
      return s;
    }).toList();

    state = state.copyWith(
      blocks: blocks,
      sessions: sessions,
      currentCwd: (sessionId == state.activeSessionId && cwd.isNotEmpty)
          ? cwd
          : state.currentCwd,
    );
  }

  void _onServerError(Map<String, dynamic> data) {
    final msg = data['message'] as String? ?? 'Error desconocido';
    _addSystemBlock(msg, isError: true);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> connectWithConfig(ConnectionConfig config) async {
    if (state.connectionStatus.isConnecting ||
        state.connectionStatus.isConnected) {
      return;
    }

    // Recreate transport if type changed
    final currentType = _transportType();
    if (config.transportType != currentType) {
      _eventSub?.cancel();
      _statusSub?.cancel();
      _transport.dispose();
      _transport = createTransport(config.transportType);
      _subscribe();
    }

    state = state.copyWith(connectionStatus: SessionStatus.connecting);
    _config = config;

    try {
      final token = await _authenticate(config);
      await _transport.connect(config, token);
    } catch (e) {
      state = state.copyWith(connectionStatus: SessionStatus.error);
      _addSystemBlock('Error de conexión: $e', isError: true);
      _scheduleAutoRetry(config);
    }
  }

  Future<void> disconnect() async {
    _autoRetryTimer?.cancel();
    await _transport.disconnect();
    state = state.copyWith(connectionStatus: SessionStatus.disconnected);
    _addSystemBlock('Desconectado de JARVIS');
  }

  void sendCommand(String text) {
    if (!state.connectionStatus.isConnected) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Reset (or create) the xterm terminal for this session.
    // \x1bc = RIS (Reset to Initial State) — clears screen and history.
    _getOrCreateTerminal(state.activeSessionId).write('\x1bc');

    final block = TerminalBlock.command(
      command: trimmed,
      cwd: state.currentCwd,
      sessionId: state.activeSessionId,
    );
    state = state.copyWith(blocks: _trim([...state.blocks, block]));
    _transport.send({
      'type': 'input',
      'data': '$trimmed\r',
      'session': state.activeSessionId,
    });
  }

  void sendRawInput(String data, {String? sessionId}) {
    _transport.send({
      'type': 'input',
      'data': data,
      'session': sessionId ?? state.activeSessionId,
    });
  }

  void sendSignal(String signal) => sendRawInput(signal);

  void newSession() {
    _transport.send({'type': 'session_new'});
  }

  void closeSession(String sessionId) {
    _transport.send({'type': 'session_close', 'id': sessionId});
  }

  void setActiveSession(String sessionId) {
    if (state.sessions.every((s) => s.id != sessionId)) return;
    final sessions = state.sessions
        .map((s) => s.copyWith(isActive: s.id == sessionId))
        .toList();
    final cwd =
        sessions.where((s) => s.id == sessionId).firstOrNull?.cwd ??
            state.currentCwd;
    state = state.copyWith(
      sessions: sessions,
      activeSessionId: sessionId,
      currentCwd: cwd,
    );
  }

  void resizePty(int cols, int rows, {String? sessionId}) {
    _transport.send({
      'type': 'resize',
      'cols': cols,
      'rows': rows,
      'session': sessionId ?? state.activeSessionId,
    });
  }

  void clearBlocks() {
    state = state.copyWith(blocks: []);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addSystemBlock(String message, {bool isError = false}) {
    final block = TerminalBlock.system(
      message: message,
      cwd: state.currentCwd,
      sessionId: state.activeSessionId,
      isError: isError,
    );
    state = state.copyWith(blocks: _trim([...state.blocks, block]));
  }

  void _scheduleAutoRetry(ConnectionConfig config) {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer(AppConstants.autoRetryDelay, () {
      if (!state.connectionStatus.isConnected &&
          !state.connectionStatus.isConnecting) {
        connectWithConfig(config);
      }
    });
  }

  int _lastRunningBlock(List<TerminalBlock> blocks, String sessionId) {
    for (int i = blocks.length - 1; i >= 0; i--) {
      if (blocks[i].sessionId == sessionId && blocks[i].isRunning) return i;
    }
    return -1;
  }

  List<TerminalBlock> _trim(List<TerminalBlock> blocks) {
    if (blocks.length <= AppConstants.maxMessages) return blocks;
    return blocks.sublist(blocks.length - AppConstants.maxMessages);
  }

  TransportType _transportType() {
    return _config?.transportType ?? TransportType.direct;
  }

  @override
  void dispose() {
    _terminals.clear();
    _eventSub?.cancel();
    _statusSub?.cancel();
    _autoRetryTimer?.cancel();
    _transport.dispose();
    super.dispose();
  }
}

// ── Auth helper (standalone HTTP call) ───────────────────────────────────────

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
    if (token == null || token.isEmpty) throw Exception('Token vacío del servidor');
    return token;
  } else if (response.statusCode == 401) {
    throw Exception('Credenciales incorrectas o dispositivo no autorizado');
  } else if (response.statusCode == 429) {
    throw Exception('Demasiados intentos. Espera 15 minutos.');
  }
  throw Exception('Error del servidor: ${response.statusCode}');
}

// ── Provider ──────────────────────────────────────────────────────────────────

final terminalProvider =
    StateNotifierProvider<TerminalNotifier, TerminalState>((ref) {
  final transport = createTransport(TransportType.direct);
  return TerminalNotifier(transport);
});
