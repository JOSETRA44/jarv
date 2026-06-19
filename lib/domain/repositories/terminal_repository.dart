import '../entities/session_state.dart';

abstract class TerminalRepository {
  /// Stream of incoming messages from JARVIS
  Stream<Map<String, dynamic>> get messageStream;

  /// Current session state
  SessionState get currentSessionState;

  /// Connect to JARVIS WebSocket
  Future<void> connect({required String wsUrl, required String token});

  /// Disconnect from JARVIS WebSocket
  Future<void> disconnect();

  /// Send a command to JARVIS
  Future<void> sendCommand(String text);

  /// Send a control signal
  Future<void> sendSignal(String signal);

  /// Send raw message
  Future<void> sendRaw(Map<String, dynamic> data);

  /// Is currently connected
  bool get isConnected;
}
