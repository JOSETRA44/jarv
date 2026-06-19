import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/connection_config_model.dart';

class ConfigLocalDatasource {
  Future<ConnectionConfigModel?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.prefBaseUrl);
    if (json == null) {
      // Try loading from individual keys (legacy support)
      final baseUrl = prefs.getString(AppConstants.prefBaseUrl);
      final password = prefs.getString(AppConstants.prefPassword);
      if (baseUrl != null && password != null) {
        return ConnectionConfigModel(baseUrl: baseUrl, password: password);
      }
      return null;
    }
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return ConnectionConfigModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(ConnectionConfigModel config) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(config.toJson());
    await prefs.setString('jarvis_config', json);
  }

  Future<ConnectionConfigModel?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('jarvis_config');
    if (json == null) return null;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return ConnectionConfigModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jarvis_config');
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefThemeMode, mode);
  }

  Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefThemeMode) ?? 'dark';
  }
}
