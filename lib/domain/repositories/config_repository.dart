import '../entities/connection_config.dart';

abstract class ConfigRepository {
  /// Load saved configuration from local storage
  Future<ConnectionConfig?> load();

  /// Save configuration to local storage
  Future<void> save(ConnectionConfig config);

  /// Clear all stored configuration
  Future<void> clear();

  /// Save theme mode preference
  Future<void> saveThemeMode(String mode);

  /// Load theme mode preference
  Future<String> loadThemeMode();
}
