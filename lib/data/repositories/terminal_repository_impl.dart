import '../../domain/entities/session_state.dart';
import '../../domain/repositories/terminal_repository.dart';
import '../datasources/remote/jarvis_ws_datasource.dart';

class TerminalRepositoryImpl implements TerminalRepository {
  final JarvisWsDatasource _datasource;

  SessionState _sessionState = const SessionState.disconnected();

  TerminalRepositoryImpl(this._datasource);

  @override
  Stream<Map<String, dynamic>> get messageStream => _datasource.messageStream;

  @override
  SessionState get currentSessionState => _sessionState;

  @override
  bool get isConnected => _datasource.isConnected;

  @override
  Future<void> connect({required String wsUrl, required String token}) async {
    _sessionState = const SessionState.connecting();
    await _datasource.connect(wsUrl, token);
  }

  @override
  Future<void> disconnect() async {
    await _datasource.disconnect();
    _sessionState = const SessionState.disconnected();
  }

  @override
  Future<void> sendCommand(String text) async {
    await _datasource.sendCommand(text);
  }

  @override
  Future<void> sendSignal(String signal) async {
    await _datasource.sendSignal(signal);
  }

  @override
  Future<void> sendRaw(Map<String, dynamic> data) async {
    await _datasource.sendMessage(data);
  }
}
