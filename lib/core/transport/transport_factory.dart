import '../../domain/entities/connection_config.dart';
import 'i_transport_strategy.dart';
import 'websocket_transport.dart';

ITransportStrategy createTransport(TransportType type) {
  switch (type) {
    case TransportType.direct:
    case TransportType.cloudflare:
      return WebSocketTransport();
    case TransportType.telegram:
      throw UnimplementedError('Telegram transport — próximamente');
  }
}
