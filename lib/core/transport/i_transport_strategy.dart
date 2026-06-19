import '../../domain/entities/connection_config.dart';

abstract class ITransportStrategy {
  Stream<Map<String, dynamic>> get events;

  /// Status strings: connecting, connected, disconnected, error:msg
  Stream<String> get statusStream;

  bool get isConnected;

  Future<void> connect(ConnectionConfig config, String token);
  Future<void> send(Map<String, dynamic> message);
  Future<void> disconnect();
  void dispose();
}
