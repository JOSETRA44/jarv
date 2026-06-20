import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User toggle for local notifications, persisted in SharedPreferences.
/// Default off until the user enables it (which also requests OS permission).
class NotificationSettingsNotifier extends StateNotifier<bool> {
  static const _prefKey = 'jarvis_notifications_enabled';

  NotificationSettingsNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }
}

final notificationsEnabledProvider =
    StateNotifierProvider<NotificationSettingsNotifier, bool>(
  (ref) => NotificationSettingsNotifier(),
);
