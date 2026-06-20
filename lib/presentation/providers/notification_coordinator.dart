import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/services/i_notification_service.dart';
import '../../infrastructure/notifications/local_notification_service.dart';
import 'app_lifecycle_provider.dart';
import 'notification_settings_provider.dart';
import 'poltergeist_provider.dart';
import 'terminal_provider.dart';

/// Only commands longer than this raise a "finished" notification.
const _longCmdMs = 10000;

/// Bridges existing app events to local notifications, keeping notification
/// concerns out of the business providers. Notifications are gated on:
///   1. the user toggle (notificationsEnabledProvider)
///   2. the app being in the background (don't disturb while foregrounded)
class NotificationCoordinator {
  final Ref _ref;
  final INotificationService _service = LocalNotificationService.instance;
  StreamSubscription? _eventsSub;
  bool _hadOutage = false;

  NotificationCoordinator(this._ref) {
    // Connection lost / reconnected — edge-detected from connection status.
    _ref.listen<SessionStatus>(
      terminalProvider.select((s) => s.connectionStatus),
      (prev, next) => _onStatus(prev, next),
    );

    // Long command finished / session exited — from the server event stream.
    _eventsSub =
        _ref.read(terminalProvider.notifier).serverEvents.listen(_onServerEvent);

    // Control action failed.
    _ref.listen<(String?, bool?, String?)>(
      poltergeistProvider
          .select((s) => (s.lastActionId, s.lastSuccess, s.lastOutput)),
      (prev, next) {
        final (id, ok, out) = next;
        if (ok == false && id != null && id.isNotEmpty) {
          _notify(
            NotificationKind.controlFailed,
            title: 'Acción fallida',
            body: out?.isNotEmpty == true ? out! : 'La acción "$id" falló',
          );
        }
      },
    );
  }

  void _onStatus(SessionStatus? prev, SessionStatus next) {
    if (next == SessionStatus.connected) {
      if (_hadOutage) {
        _hadOutage = false;
        _notify(
          NotificationKind.reconnected,
          title: 'Reconectado',
          body: 'Conexión con JARVIS restablecida.',
        );
      }
    } else if (next == SessionStatus.disconnected ||
        next == SessionStatus.error) {
      if (prev == SessionStatus.connected) {
        _hadOutage = true;
        _notify(
          NotificationKind.connectionLost,
          title: 'Conexión perdida',
          body: 'Se perdió la conexión con JARVIS.',
        );
      }
    }
  }

  void _onServerEvent(Map<String, dynamic> data) {
    switch (data['type'] as String?) {
      case 'prompt':
        final ms = data['durationMs'] as int?;
        if (ms != null && ms >= _longCmdMs) {
          final exit = data['exitCode'] as int? ?? 0;
          _notify(
            NotificationKind.longCommand,
            title: 'Comando finalizado',
            body: 'Terminó en ${(ms / 1000).toStringAsFixed(0)}s (exit $exit).',
          );
        }
      case 'session_exit':
        final exit = data['exitCode'] as int? ?? 0;
        _notify(
          NotificationKind.sessionEnded,
          title: 'Sesión finalizada',
          body: 'Un proceso terminó (exit $exit).',
        );
    }
  }

  Future<void> _notify(
    NotificationKind kind, {
    required String title,
    required String body,
  }) async {
    // Don't disturb while the user is actively looking at the app.
    if (_ref.read(isForegroundProvider)) return;
    if (!_ref.read(notificationsEnabledProvider)) return;
    await _service.show(kind, title: title, body: body);
  }

  void dispose() {
    _eventsSub?.cancel();
  }
}

final notificationCoordinatorProvider = Provider<NotificationCoordinator>((ref) {
  final coord = NotificationCoordinator(ref);
  ref.onDispose(coord.dispose);
  return coord;
});
