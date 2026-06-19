import '../../domain/entities/connection_config.dart';
import '../../domain/repositories/config_repository.dart';
import '../datasources/local/config_local_datasource.dart';
import '../models/connection_config_model.dart';

class ConfigRepositoryImpl implements ConfigRepository {
  final ConfigLocalDatasource _datasource;

  ConfigRepositoryImpl(this._datasource);

  @override
  Future<ConnectionConfig?> load() async {
    return _datasource.load();
  }

  @override
  Future<void> save(ConnectionConfig config) async {
    final model = ConnectionConfigModel.fromEntity(config);
    await _datasource.saveConfig(model);
  }

  @override
  Future<void> clear() async {
    await _datasource.clear();
  }

  @override
  Future<void> saveThemeMode(String mode) async {
    await _datasource.saveThemeMode(mode);
  }

  @override
  Future<String> loadThemeMode() async {
    return _datasource.loadThemeMode();
  }
}
