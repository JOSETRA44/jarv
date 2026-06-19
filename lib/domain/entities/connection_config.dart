enum TransportType {
  direct,
  telegram,
  cloudflare,
}

extension TransportTypeExtension on TransportType {
  String get displayName {
    switch (this) {
      case TransportType.direct:
        return 'Direct';
      case TransportType.telegram:
        return 'Telegram';
      case TransportType.cloudflare:
        return 'Cloudflare';
    }
  }

  bool get isAvailable {
    switch (this) {
      case TransportType.direct:
        return true;
      case TransportType.telegram:
        return false;
      case TransportType.cloudflare:
        return false;
    }
  }
}

class ConnectionConfig {
  final String baseUrl;
  final String password;
  final String? operatorId;
  final TransportType transportType;

  const ConnectionConfig({
    required this.baseUrl,
    required this.password,
    this.operatorId,
    this.transportType = TransportType.direct,
  });

  ConnectionConfig copyWith({
    String? baseUrl,
    String? password,
    String? operatorId,
    TransportType? transportType,
  }) {
    return ConnectionConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      password: password ?? this.password,
      operatorId: operatorId ?? this.operatorId,
      transportType: transportType ?? this.transportType,
    );
  }

  /// Convert http:// to ws:// for WebSocket URL
  String get wsUrl {
    final normalized = baseUrl.trim();
    if (normalized.startsWith('https://')) {
      return normalized.replaceFirst('https://', 'wss://');
    } else if (normalized.startsWith('http://')) {
      return normalized.replaceFirst('http://', 'ws://');
    } else if (normalized.startsWith('ws://') || normalized.startsWith('wss://')) {
      return normalized;
    }
    return 'ws://$normalized';
  }

  String get httpUrl {
    final normalized = baseUrl.trim();
    if (normalized.startsWith('ws://')) {
      return normalized.replaceFirst('ws://', 'http://');
    } else if (normalized.startsWith('wss://')) {
      return normalized.replaceFirst('wss://', 'https://');
    } else if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    return 'http://$normalized';
  }

  @override
  String toString() =>
      'ConnectionConfig(baseUrl: $baseUrl, transport: $transportType)';
}
