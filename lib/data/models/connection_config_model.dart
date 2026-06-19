import '../../domain/entities/connection_config.dart';

class ConnectionConfigModel extends ConnectionConfig {
  const ConnectionConfigModel({
    required super.baseUrl,
    required super.password,
    super.operatorId,
    super.transportType,
  });

  factory ConnectionConfigModel.fromEntity(ConnectionConfig entity) {
    return ConnectionConfigModel(
      baseUrl: entity.baseUrl,
      password: entity.password,
      operatorId: entity.operatorId,
      transportType: entity.transportType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'password': password,
      'operatorId': operatorId,
      'transportType': transportType.name,
    };
  }

  factory ConnectionConfigModel.fromJson(Map<String, dynamic> json) {
    return ConnectionConfigModel(
      baseUrl: json['baseUrl'] as String? ?? '',
      password: json['password'] as String? ?? '',
      operatorId: json['operatorId'] as String?,
      transportType: TransportType.values.firstWhere(
        (e) => e.name == json['transportType'],
        orElse: () => TransportType.direct,
      ),
    );
  }
}
