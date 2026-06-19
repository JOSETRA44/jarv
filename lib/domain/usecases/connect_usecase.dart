import 'dart:convert';
import 'package:http/http.dart' as http;
import '../entities/connection_config.dart';
import '../repositories/terminal_repository.dart';
import '../../core/constants/app_constants.dart';

class ConnectUsecase {
  final TerminalRepository _terminalRepository;

  ConnectUsecase(this._terminalRepository);

  /// Authenticate via HTTP and then open WebSocket
  Future<String> authenticate(ConnectionConfig config) async {
    final loginUrl = '${config.httpUrl}${AppConstants.loginPath}';

    final response = await http
        .post(
          Uri.parse(loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'password': config.password}),
        )
        .timeout(AppConstants.requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('No token received from server');
      }
      return token;
    } else if (response.statusCode == 401) {
      throw Exception('Contraseña incorrecta');
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  Future<void> connect(ConnectionConfig config, String token) async {
    final wsUrl = '${config.wsUrl}${AppConstants.wsMobilePath}';
    await _terminalRepository.connect(wsUrl: wsUrl, token: token);
  }

  Future<void> disconnect() async {
    await _terminalRepository.disconnect();
  }
}
