import '../repositories/terminal_repository.dart';

class SendCommandUsecase {
  final TerminalRepository _terminalRepository;

  SendCommandUsecase(this._terminalRepository);

  Future<void> execute(String command) async {
    if (command.trim().isEmpty) return;
    if (!_terminalRepository.isConnected) {
      throw Exception('No hay conexión activa con JARVIS');
    }
    await _terminalRepository.sendCommand(command.trim());
  }

  Future<void> sendSignal(String signal) async {
    if (!_terminalRepository.isConnected) return;
    await _terminalRepository.sendSignal(signal);
  }
}
