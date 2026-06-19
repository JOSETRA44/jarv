import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/terminal_message.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/entities/connection_config.dart';
import '../../domain/repositories/terminal_repository.dart';
import '../../domain/usecases/connect_usecase.dart';
import '../../domain/usecases/send_command_usecase.dart';
import '../../data/datasources/remote/jarvis_ws_datasource.dart';
import '../../data/repositories/terminal_repository_impl.dart';


// Infrastructure providers
final jarvisWsDatasourceProvider = Provider<JarvisWsDatasource>((ref) {
  final datasource = JarvisWsDatasource();
  ref.onDispose(() => datasource.dispose());
  return datasource;
});

final terminalRepositoryProvider = Provider<TerminalRepository>((ref) {
  final datasource = ref.watch(jarvisWsDatasourceProvider);
  return TerminalRepositoryImpl(datasource);
});

final connectUsecaseProvider = Provider<ConnectUsecase>((ref) {
  final repo = ref.watch(terminalRepositoryProvider);
  return ConnectUsecase(repo);
});

final sendCommandUsecaseProvider = Provider<SendCommandUsecase>((ref) {
  final repo = ref.watch(terminalRepositoryProvider);
  return SendCommandUsecase(repo);
});

// Terminal state
class TerminalState {
  final List<TerminalMessage> messages;
  final SessionState sessionState;
  final bool isInteractive;
  final String? interactiveProcessName;
  final String currentCwd;
  final bool isSending;
  final String? pendingCommandId;

  const TerminalState({
    this.messages = const [],
    this.sessionState = const SessionState.disconnected(),
    this.isInteractive = false,
    this.interactiveProcessName,
    this.currentCwd = '',
    this.isSending = false,
    this.pendingCommandId,
  });

  TerminalState copyWith({
    List<TerminalMessage>? messages,
    SessionState? sessionState,
    bool? isInteractive,
    String? interactiveProcessName,
    String? currentCwd,
    bool? isSending,
    String? pendingCommandId,
  }) {
    return TerminalState(
      messages: messages ?? this.messages,
      sessionState: sessionState ?? this.sessionState,
      isInteractive: isInteractive ?? this.isInteractive,
      interactiveProcessName: interactiveProcessName ?? this.interactiveProcessName,
      currentCwd: currentCwd ?? this.currentCwd,
      isSending: isSending ?? this.isSending,
      pendingCommandId: pendingCommandId ?? this.pendingCommandId,
    );
  }
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  final TerminalRepository _repository;
  final ConnectUsecase _connectUsecase;
  final SendCommandUsecase _sendCommandUsecase;
  final _uuid = const Uuid();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _autoRetryTimer;

  TerminalNotifier(
    this._repository,
    this._connectUsecase,
    this._sendCommandUsecase,
  ) : super(const TerminalState()) {
    _listenToWsStatus();
    _listenToMessages();
  }

  void _listenToWsStatus() {
    // Status is tracked via authenticated/error messages in the stream
  }

  void _listenToMessages() {
    _messageSubscription = _repository.messageStream.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'authenticated':
        state = state.copyWith(
          sessionState: const SessionState.connected(),
        );
        _addSystemMessage('Conectado a JARVIS');
        _autoRetryTimer?.cancel();
        break;

      case 'executing':
        final cwd = data['cwd'] as String? ?? state.currentCwd;
        state = state.copyWith(currentCwd: cwd, isSending: true);
        break;

      case 'chunk':
        final text = data['text'] as String? ?? '';
        _appendToLastOutput(text);
        break;

      case 'result':
        final exitCode = data['exitCode'] as int? ?? 0;
        final cwd = data['cwd'] as String? ?? state.currentCwd;
        final output = data['output'] as String? ?? '';
        final durationMs = data['durationMs'] as int?;
        _finalizeOutput(exitCode, cwd, output, durationMs);
        state = state.copyWith(
          currentCwd: cwd,
          isSending: false,
          pendingCommandId: null,
        );
        break;

      case 'interactive_start':
        final command = data['command'] as String? ?? '';
        state = state.copyWith(
          isInteractive: true,
          interactiveProcessName: command,
          isSending: false,
        );
        _addInteractiveMessage(command, '');
        break;

      case 'interactive_chunk':
        final text = data['text'] as String? ?? '';
        _updateLastInteractiveMessage(text);
        break;

      case 'interactive_end':
        final exitCode = data['exitCode'] as int? ?? 0;
        state = state.copyWith(
          isInteractive: false,
          interactiveProcessName: null,
          isSending: false,
        );
        _addSystemMessage(
          'Proceso interactivo terminado (exit $exitCode)',
        );
        break;

      case 'error':
        final message = data['message'] as String? ?? 'Error desconocido';
        _addSystemMessage('Error: $message', isError: true);
        state = state.copyWith(isSending: false);
        break;
    }
  }

  void _addSystemMessage(String content, {bool isError = false}) {
    final msg = TerminalMessage(
      id: _uuid.v4(),
      type: isError ? MessageType.error : MessageType.system,
      content: content,
      timestamp: DateTime.now(),
    );
    _addMessage(msg);
  }

  void _addInteractiveMessage(String processName, String content) {
    final msg = TerminalMessage(
      id: _uuid.v4(),
      type: MessageType.interactive,
      content: content,
      timestamp: DateTime.now(),
      processName: processName,
    );
    _addMessage(msg);
  }

  void _appendToLastOutput(String chunk) {
    final messages = List<TerminalMessage>.from(state.messages);
    if (messages.isNotEmpty && messages.last.type == MessageType.output) {
      final last = messages.last;
      messages[messages.length - 1] = last.copyWith(
        content: last.content + chunk,
      );
      state = state.copyWith(messages: messages);
    } else {
      final msg = TerminalMessage(
        id: _uuid.v4(),
        type: MessageType.output,
        content: chunk,
        timestamp: DateTime.now(),
      );
      _addMessage(msg);
    }
  }

  void _finalizeOutput(int exitCode, String cwd, String output, int? durationMs) {
    final messages = List<TerminalMessage>.from(state.messages);
    if (messages.isNotEmpty && messages.last.type == MessageType.output) {
      final last = messages.last;
      // If we got a full output, use it; otherwise keep accumulated chunks
      final content = output.isNotEmpty ? output : last.content;
      messages[messages.length - 1] = last.copyWith(
        content: content,
        exitCode: exitCode,
        cwd: cwd,
        durationMs: durationMs,
      );
      state = state.copyWith(messages: messages);
    } else if (output.isNotEmpty) {
      final msg = TerminalMessage(
        id: _uuid.v4(),
        type: MessageType.output,
        content: output,
        timestamp: DateTime.now(),
        exitCode: exitCode,
        cwd: cwd,
        durationMs: durationMs,
      );
      _addMessage(msg);
    }
  }

  void _updateLastInteractiveMessage(String snapshot) {
    final messages = List<TerminalMessage>.from(state.messages);
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].type == MessageType.interactive) {
        messages[i] = messages[i].copyWith(content: snapshot);
        state = state.copyWith(messages: messages);
        return;
      }
    }
    // No interactive message found, add one
    _addInteractiveMessage(state.interactiveProcessName ?? '', snapshot);
  }

  void _addMessage(TerminalMessage message) {
    final messages = List<TerminalMessage>.from(state.messages);
    messages.add(message);
    // Keep max messages
    if (messages.length > AppConstants.maxMessages) {
      messages.removeRange(0, messages.length - AppConstants.maxMessages);
    }
    state = state.copyWith(messages: messages);
  }

  Future<void> connectWithConfig(ConnectionConfig config) async {
    if (state.sessionState.status.isConnecting || state.sessionState.status.isConnected) return;

    state = state.copyWith(sessionState: const SessionState.connecting());

    try {
      final token = await _connectUsecase.authenticate(config);

      // Update config with operator if needed
      final wsUrl = '${config.wsUrl}/ws/mobile';
      await _repository.connect(wsUrl: wsUrl, token: token);
    } catch (e) {
      state = state.copyWith(
        sessionState: SessionState.error(e.toString()),
        isSending: false,
      );
      _addSystemMessage('Error de conexión: $e', isError: true);
      _scheduleAutoRetry(config);
    }
  }

  void _scheduleAutoRetry(ConnectionConfig config) {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer(AppConstants.autoRetryDelay, () {
      if (!state.sessionState.status.isConnected && !state.sessionState.status.isConnecting) {
        connectWithConfig(config);
      }
    });
  }

  Future<void> disconnect() async {
    _autoRetryTimer?.cancel();
    await _connectUsecase.disconnect();
    state = state.copyWith(
      sessionState: const SessionState.disconnected(),
      isInteractive: false,
      interactiveProcessName: null,
      isSending: false,
    );
    _addSystemMessage('Desconectado de JARVIS');
  }

  Future<void> sendCommand(String text) async {
    if (text.trim().isEmpty) return;

    final commandId = _uuid.v4();
    final commandMsg = TerminalMessage(
      id: commandId,
      type: MessageType.command,
      content: text.trim(),
      timestamp: DateTime.now(),
      cwd: state.currentCwd,
    );
    _addMessage(commandMsg);
    state = state.copyWith(isSending: true, pendingCommandId: commandId);

    try {
      await _sendCommandUsecase.execute(text);
    } catch (e) {
      _addSystemMessage('Error: $e', isError: true);
      state = state.copyWith(isSending: false, pendingCommandId: null);
    }
  }

  Future<void> sendSignal(String signal) async {
    await _sendCommandUsecase.sendSignal(signal);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  void updateSessionState(SessionState sessionState) {
    state = state.copyWith(sessionState: sessionState);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _autoRetryTimer?.cancel();
    super.dispose();
  }
}

final terminalProvider =
    StateNotifierProvider<TerminalNotifier, TerminalState>((ref) {
  final repo = ref.watch(terminalRepositoryProvider);
  final connectUc = ref.watch(connectUsecaseProvider);
  final sendUc = ref.watch(sendCommandUsecaseProvider);
  return TerminalNotifier(repo, connectUc, sendUc);
});
