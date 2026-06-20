class AppConstants {
  AppConstants._();

  static const String appName = 'JARVIS';
  static const String appVersion = '1.0.0';

  // Default connection (LAN / Direct)
  static const String defaultBaseUrl = 'http://192.168.1.1:3000';

  // Cloudflare Tunnel public URL (alternate transport)
  static const String cloudflareBaseUrl = 'https://jarvis.unicali.app';

  // API paths
  static const String loginPath = '/api/auth/login';
  static const String wsMobilePath = '/ws/mobile';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration requestTimeout = Duration(seconds: 15);

  // Ping every 20 s — keeps connections alive through Cloudflare's 100 s idle timeout
  // and detects dead 4G/5G links faster than the old 30 s interval.
  static const Duration pingInterval = Duration(seconds: 20);

  // Reconnect backoff: first attempt is immediate (micro-cut recovery),
  // then exponential up to 15 s (capped lower than 30 s for mobile UX).
  static const Duration reconnectInitialDelay = Duration(seconds: 2);
  static const Duration reconnectMaxDelay = Duration(seconds: 15);
  static const Duration autoRetryDelay = Duration(seconds: 10);

  // SharedPreferences keys
  static const String prefBaseUrl = 'jarvis_base_url';
  static const String prefPassword = 'jarvis_password';
  static const String prefThemeMode = 'jarvis_theme_mode';
  static const String prefTransportType = 'jarvis_transport_type';

  // Quick commands
  static const List<String> quickCommands = [
    'dir /b',
    'cd ..',
    'git status',
    'pwd',
    'ls -la',
    '!node',
    '!gemini',
    'cls',
    'exit',
  ];

  // Max messages to keep in memory
  static const int maxMessages = 500;

  // Max reconnect attempts before giving up (0 = infinite)
  static const int maxReconnectAttempts = 0;
}
