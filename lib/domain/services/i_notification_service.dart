/// Categories of local notification the app can raise. Each maps to its own
/// Android channel so the user can tune them in system settings.
enum NotificationKind {
  connectionLost,
  reconnected,
  longCommand,
  sessionEnded,
  controlFailed,
}

/// Domain-level port for local notifications. Implemented in infrastructure so
/// business logic never depends on a concrete plugin.
abstract class INotificationService {
  Future<void> init();

  /// Requests OS permission (Android 13+ POST_NOTIFICATIONS). Returns whether
  /// notifications are allowed afterwards.
  Future<bool> requestPermission();

  Future<bool> isPermissionGranted();

  Future<void> show(
    NotificationKind kind, {
    required String title,
    required String body,
  });

  Future<void> cancelAll();
}
