import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../services/device_id_service.dart';
import '../../domain/entities/connection_config.dart';

/// Thrown when the server rate-limited login (HTTP 429). Carries the cooldown
/// the caller should wait before retrying.
class AuthRateLimitedException implements Exception {
  final Duration retryAfter;
  AuthRateLimitedException(this.retryAfter);
  @override
  String toString() =>
      'Límite de seguridad alcanzado. Reintenta en ${retryAfter.inSeconds}s.';
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Single source of truth for the JWT, shared by every module (Terminal,
/// Poltergeist, ...). Centralizing auth here eliminates the self-DDoS that came
/// from each module hitting POST /api/auth/login independently on every
/// reconnect:
///
///   - **Token cache**: a valid token is reused without any network call, so WS
///     reconnections cost zero logins.
///   - **Single-flight**: concurrent callers share one in-flight POST instead of
///     racing N requests.
///   - **429 cooldown**: on rate-limit, [getToken] fails fast (no network) until
///     the cooldown — honoring the server's Retry-After — so the client never
///     hammers the endpoint.
class AuthService {
  String? _token;
  DateTime? _expiresAt;
  Future<String>? _inflight;
  DateTime? _cooldownUntil;

  /// Default cooldown when the server doesn't send a Retry-After header.
  static const _defaultCooldown = Duration(seconds: 60);
  /// Safety margin subtracted from the JWT expiry so we refresh slightly early.
  static const _expiryMargin = Duration(minutes: 2);

  /// Remaining cooldown after a 429, or null if not rate-limited.
  Duration? get cooldownRemaining {
    final until = _cooldownUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left > Duration.zero ? left : null;
  }

  bool get _hasValidToken {
    final t = _token;
    final exp = _expiresAt;
    if (t == null || t.isEmpty) return false;
    if (exp == null) return true; // couldn't parse exp → assume usable
    return DateTime.now().isBefore(exp.subtract(_expiryMargin));
  }

  /// Drop the cached token (e.g. the WS server reported it expired/invalid).
  void invalidate() {
    _token = null;
    _expiresAt = null;
  }

  /// Returns a valid JWT, authenticating only when necessary.
  ///
  /// Throws [AuthRateLimitedException] while in a 429 cooldown, or
  /// [AuthException] on other failures.
  Future<String> getToken(ConnectionConfig config,
      {bool forceRefresh = false}) {
    // Fail fast during cooldown — never touch the network.
    final cd = cooldownRemaining;
    if (cd != null) throw AuthRateLimitedException(cd);

    if (!forceRefresh && _hasValidToken) return Future.value(_token!);

    // Single-flight: collapse concurrent callers onto one request.
    final existing = _inflight;
    if (existing != null) return existing;

    final future = _login(config);
    _inflight = future;
    // Clear the in-flight slot once it settles (success or failure).
    future.whenComplete(() {
      if (identical(_inflight, future)) _inflight = null;
    });
    return future;
  }

  Future<String> _login(ConnectionConfig config) async {
    final deviceId = await DeviceIdService.get();
    final url = Uri.parse('${config.httpUrl}${AppConstants.loginPath}');

    final http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body:
                jsonEncode({'password': config.password, 'deviceId': deviceId}),
          )
          .timeout(AppConstants.requestTimeout);
    } catch (e) {
      throw AuthException('Error de red: $e');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Token vacío del servidor');
      }
      _token = token;
      _expiresAt = _parseJwtExpiry(token);
      _cooldownUntil = null;
      return token;
    }

    if (response.statusCode == 429) {
      _cooldownUntil = DateTime.now().add(_retryAfter(response));
      throw AuthRateLimitedException(cooldownRemaining ?? _defaultCooldown);
    }

    if (response.statusCode == 401) {
      throw AuthException('Credenciales incorrectas o dispositivo no autorizado');
    }
    throw AuthException('Error del servidor: ${response.statusCode}');
  }

  Duration _retryAfter(http.Response response) {
    final header = response.headers['retry-after'];
    final secs = header != null ? int.tryParse(header.trim()) : null;
    if (secs != null && secs > 0) return Duration(seconds: secs);
    return _defaultCooldown;
  }

  /// Reads the `exp` claim (seconds since epoch) from a JWT, if present.
  DateTime? _parseJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
