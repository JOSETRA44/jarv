import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_provider.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final dynamic _repository;

  ThemeNotifier(this._repository) : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    try {
      final mode = await _repository.loadThemeMode();
      state = _fromString(mode);
    } catch (_) {
      state = ThemeMode.dark;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _repository.saveThemeMode(_toString(mode));
  }

  Future<void> toggle() async {
    if (state == ThemeMode.dark) {
      await setTheme(ThemeMode.light);
    } else {
      await setTheme(ThemeMode.dark);
    }
  }

  ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      default:
        return 'dark';
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final repo = ref.watch(configRepositoryProvider);
  return ThemeNotifier(repo);
});
