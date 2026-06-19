import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/constants/app_constants.dart';

class JarvisWsDatasource {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get statusStream => _statusController.stream;

  String? _wsUrl;
  String? _token;
  bool _isConnected = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;

  bool get isConnected => _isConnected;

  Future<void> connect(String wsUrl, String token) async {
    _wsUrl = wsUrl;
    _token = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    _setStatus('connecting');
    try {
      final uri = Uri.parse(_wsUrl!);
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to be established
      await _channel!.ready.timeout(AppConstants.connectTimeout);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Send auth message
      _sendRaw({'type': 'auth', 'token': _token!});
      _startPing();
      _reconnectAttempts = 0;
    } catch (e) {
      _onError(e);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'authenticated') {
        _isConnected = true;
        _setStatus('connected');
        _messageController.add(data);
        return;
      }

      if (type == 'pong') {
        // Ping is alive, no action needed
        return;
      }

      _messageController.add(data);
    } catch (_) {
      // Ignore parse errors
    }
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _setStatus('error:${error.toString()}');
    _cleanup();
    _scheduleReconnect();
  }

  void _onDone() {
    _isConnected = false;
    _setStatus('disconnected');
    _cleanup();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectAttempts++;
    final delay = _reconnectDelay(_reconnectAttempts);

    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect) {
        _doConnect();
      }
    });
  }

  Duration _reconnectDelay(int attempt) {
    final seconds = min(
      AppConstants.reconnectInitialDelay.inSeconds * pow(2, attempt - 1),
      AppConstants.reconnectMaxDelay.inSeconds.toDouble(),
    );
    return Duration(seconds: seconds.toInt());
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) {
      if (_isConnected) {
        _sendRaw({'type': 'ping'});
      }
    });
  }

  void _sendRaw(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {
      // Channel might be closed
    }
  }

  Future<void> sendCommand(String text) async {
    if (!_isConnected) throw Exception('WebSocket not connected');
    _sendRaw({'type': 'command', 'text': text});
  }

  Future<void> sendSignal(String signal) async {
    if (!_isConnected) return;
    _sendRaw({'type': 'signal', 'signal': signal});
  }

  Future<void> sendMessage(Map<String, dynamic> data) async {
    _sendRaw(data);
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    _cleanup();
    _setStatus('disconnected');
  }

  void _setStatus(String status) {
    _statusController.add(status);
  }

  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    _messageController.close();
    _statusController.close();
  }
}
