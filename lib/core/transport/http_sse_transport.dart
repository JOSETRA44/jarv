import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../../domain/entities/connection_config.dart';
import 'i_transport_strategy.dart';

/// HTTP Server-Sent Events transport — fallback when WebSocket is blocked.
///
/// Reads events via GET /api/mobile/events (SSE stream).
/// Sends commands via POST /api/mobile/command (JSON body).
///
/// Mirrors WebSocketTransport's backoff and status semantics so TerminalNotifier
/// can treat both implementations identically.
class HttpSseTransport implements ITransportStrategy {
  final _client = http.Client();
  StreamSubscription? _sseSub;
  Timer? _reconnectTimer;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _status = StreamController<String>.broadcast();

  ConnectionConfig? _config;
  String? _token;
  bool _connected = false;
  bool _shouldReconnect = false;
  int _attempts = 0;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Stream<String> get statusStream => _status.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(ConnectionConfig config, String token) async {
    _config = config;
    _token = token;
    _shouldReconnect = true;
    _attempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    _status.add('connecting');
    try {
      final uri = Uri.parse('${_config!.httpUrl}/api/mobile/events');
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $_token'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final response = await _client.send(request).timeout(AppConstants.connectTimeout);
      if (response.statusCode != 200) {
        throw Exception('SSE status ${response.statusCode}');
      }

      _connected = true;
      _attempts = 0;
      // authenticated event will arrive in the stream data and trigger status update

      String buffer = '';
      _sseSub = response.stream.transform(const Utf8Decoder()).listen(
        (chunk) {
          buffer += chunk;
          final parts = buffer.split('\n\n');
          buffer = parts.removeLast();
          for (final block in parts) {
            for (final line in block.split('\n')) {
              if (!line.startsWith('data:')) continue;
              final jsonStr = line.substring(5).trim();
              if (jsonStr.isEmpty) continue;
              try {
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                if (data['type'] == 'authenticated') {
                  _status.add('connected');
                }
                _events.add(data);
              } catch (_) {}
            }
          }
        },
        onError: (e) {
          _connected = false;
          _status.add('error:${e.toString()}');
          _sseSub?.cancel();
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _status.add('disconnected');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _connected = false;
      _status.add('error:${e.toString()}');
      _scheduleReconnect();
    }
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

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_config == null || _token == null) return;
    try {
      await _client.post(
        Uri.parse('${_config!.httpUrl}/api/mobile/command'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(message),
      ).timeout(AppConstants.requestTimeout);
    } catch (_) {}
  }

  @override
  void reconnectNow() {
    if (!_shouldReconnect || _connected) return;
    _reconnectTimer?.cancel();
    _attempts = 0;
    _doConnect();
  }

  @override
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _connected = false;
    await _sseSub?.cancel();
    _sseSub = null;
    _status.add('disconnected');
  }

  @override
  void dispose() {
    disconnect();
    _events.close();
    _status.close();
    _client.close();
  }
}
