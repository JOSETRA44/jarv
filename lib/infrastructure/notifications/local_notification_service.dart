import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/services/i_notification_service.dart';

/// Local notifications via flutter_local_notifications (+ permission_handler for
/// Android 13+ POST_NOTIFICATIONS). One Android channel per [NotificationKind].
class LocalNotificationService implements INotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channels = <NotificationKind, (String id, String name, String desc)>{
    NotificationKind.connectionLost:
        ('conn_lost', 'Conexión perdida', 'Avisos de desconexión'),
    NotificationKind.reconnected:
        ('reconnected', 'Reconectado', 'Avisos de reconexión'),
    NotificationKind.longCommand:
        ('long_cmd', 'Comando finalizado', 'Comandos largos completados'),
    NotificationKind.sessionEnded:
        ('session_end', 'Sesión finalizada', 'Sesiones o procesos terminados'),
    NotificationKind.controlFailed:
        ('control_fail', 'Acción fallida', 'Acciones de Control fallidas'),
  };

  @override
  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Pre-create channels (Android 8+).
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      for (final entry in _channels.values) {
        await androidImpl.createNotificationChannel(
          AndroidNotificationChannel(
            entry.$1,
            entry.$2,
            description: entry.$3,
            importance: Importance.high,
          ),
        );
      }
    }
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Future<bool> isPermissionGranted() async {
    return Permission.notification.isGranted;
  }

  @override
  Future<void> show(
    NotificationKind kind, {
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    final (id, name, desc) = _channels[kind]!;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: desc,
        importance: Importance.high,
        priority: Priority.high,
        ticker: title,
      ),
    );
    // One active notification per kind (id = kind.index) so repeats replace.
    await _plugin.show(kind.index, title, body, details);
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
