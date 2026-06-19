import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/connection_config.dart';
import '../../domain/repositories/config_repository.dart';
import '../../data/datasources/local/config_local_datasource.dart';
import '../../data/repositories/config_repository_impl.dart';

// Providers

final configLocalDatasourceProvider = Provider<ConfigLocalDatasource>((ref) {
  return ConfigLocalDatasource();
});

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  final datasource = ref.watch(configLocalDatasourceProvider);
  return ConfigRepositoryImpl(datasource);
});

// Config state
class ConfigState {
  final ConnectionConfig? config;
  final bool isLoading;
  final String? error;

  const ConfigState({
    this.config,
    this.isLoading = false,
    this.error,
  });

  ConfigState copyWith({
    ConnectionConfig? config,
    bool? isLoading,
    String? error,
  }) {
    return ConfigState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get hasConfig => config != null;
}

class ConfigNotifier extends StateNotifier<ConfigState> {
  final ConfigRepository _repository;

  ConfigNotifier(this._repository) : super(const ConfigState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await _repository.load();
      state = ConfigState(config: config, isLoading: false);
    } catch (e) {
      state = ConfigState(isLoading: false, error: e.toString());
    }
  }

  Future<void> save(ConnectionConfig config) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.save(config);
      state = ConfigState(config: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> clear() async {
    await _repository.clear();
    state = const ConfigState();
  }

  Future<void> reload() => _load();
}

final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>((ref) {
  final repo = ref.watch(configRepositoryProvider);
  return ConfigNotifier(repo);
});
