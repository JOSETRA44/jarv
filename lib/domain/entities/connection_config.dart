enum TransportType {
  direct,
  telegram,
  cloudflare,
}

extension TransportTypeExtension on TransportType {
  String get displayName {
    switch (this) {
      case TransportType.direct:
        return 'Direct (LAN)';
      case TransportType.telegram:
        return 'Telegram';
      case TransportType.cloudflare:
        return 'Cloudflare Tunnel';
    }
  }

  bool get isAvailable {
    switch (this) {
      case TransportType.direct:
        return true;
      case TransportType.telegram:
        return false;
      case TransportType.cloudflare:
        return true;
    }
  }
}

class ConnectionConfig {
  final String baseUrl;

  /// Public Cloudflare Tunnel URL. Defaults to jarvis.unicali.app.
  /// Used automatically when transportType == cloudflare.
  final String cloudflareUrl;

  final String password;
  final String? operatorId;
  final TransportType transportType;

  const ConnectionConfig({
    required this.baseUrl,
    required this.password,
    this.cloudflareUrl = 'https://jarvis.unicali.app',
    this.operatorId,
    this.transportType = TransportType.direct,
  });

  ConnectionConfig copyWith({
    String? baseUrl,
    String? cloudflareUrl,
    String? password,
    String? operatorId,
    TransportType? transportType,
  }) {
    return ConnectionConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      cloudflareUrl: cloudflareUrl ?? this.cloudflareUrl,
      password: password ?? this.password,
      operatorId: operatorId ?? this.operatorId,
      transportType: transportType ?? this.transportType,
    );
  }

  /// The base URL actually used for this transport type.
  String get _effectiveBase =>
      transportType == TransportType.cloudflare ? cloudflareUrl : baseUrl;

  /// HTTP/HTTPS URL for REST calls (login, etc.).
  String get httpUrl {
    final s = _effectiveBase.trim();
    if (s.startsWith('ws://'))  return s.replaceFirst('ws://', 'http://');
    if (s.startsWith('wss://')) return s.replaceFirst('wss://', 'https://');
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s';
  }

  /// WSS/WS URL for WebSocket connections.
  String get wsUrl {
    final s = _effectiveBase.trim();
    if (s.startsWith('https://')) return s.replaceFirst('https://', 'wss://');
    if (s.startsWith('http://'))  return s.replaceFirst('http://', 'ws://');
    if (s.startsWith('ws://') || s.startsWith('wss://')) return s;
    return 'ws://$s';
  }

  @override
  String toString() =>
      'ConnectionConfig(transport: $transportType, url: ${httpUrl})';
}
