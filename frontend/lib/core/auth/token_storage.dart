import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores JWT tokens in encrypted device storage.
/// Never use SharedPreferences for tokens.
class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  /// Decode JWT payload without verifying signature.
  /// Verification happens server-side on every request.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      // Pad to valid base64
      payload += '=' * ((4 - payload.length % 4) % 4);
      final bytes = base64Url.decode(payload);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Extract roles list from access token claims.
  static List<String> getRolesFromToken(String token) {
    final payload = decodePayload(token);
    if (payload == null) return [];
    final roles = payload['roles'];
    if (roles is List) return roles.cast<String>();
    return [];
  }

  /// True if access token is expired (with 30s buffer for clock skew).
  static bool isTokenExpired(String token) {
    final payload = decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return true;
    final expiry = DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    return DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 30)));
  }
}
