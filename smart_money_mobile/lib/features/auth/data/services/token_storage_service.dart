// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorageService {
  // Keep the public parameter name stable for callers/tests.
  const TokenStorageService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _accessTokenExpiresAtKey = 'access_token_expires_at';
  static const _keys = [
    _accessTokenKey,
    _refreshTokenKey,
    _accessTokenExpiresAtKey,
  ];

  final FlutterSecureStorage _storage;

  // Native platforms keep tokens ONLY in secure storage. Web keeps a
  // SharedPreferences copy because secure storage can reject reads after a
  // browser reload.
  static bool get _usesPreferencesFallback => kIsWeb;

  static bool _legacyPurged = false;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
  }) async {
    final expiresAt = accessTokenExpiresAt.toUtc().toIso8601String();

    if (_usesPreferencesFallback) {
      final preferences = await SharedPreferences.getInstance();

      await Future.wait([
        preferences.setString(_accessTokenKey, accessToken),
        preferences.setString(_refreshTokenKey, refreshToken),
        preferences.setString(_accessTokenExpiresAtKey, expiresAt),
      ]);

      await _trySecureWrite(_accessTokenKey, accessToken);
      await _trySecureWrite(_refreshTokenKey, refreshToken);
      await _trySecureWrite(_accessTokenExpiresAtKey, expiresAt);
      return;
    }

    await _purgeLegacyPlaintext();
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _accessTokenExpiresAtKey, value: expiresAt);
  }

  Future<String?> getAccessToken() async {
    return _readToken(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _readToken(_refreshTokenKey);
  }

  Future<DateTime?> getAccessTokenExpiresAt() async {
    final value = await _readToken(_accessTokenExpiresAtKey);

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> clearTokens() async {
    final preferences = await SharedPreferences.getInstance();

    await Future.wait([for (final key in _keys) preferences.remove(key)]);

    for (final key in _keys) {
      await _trySecureDelete(key);
    }
  }

  Future<String?> _readToken(String key) async {
    if (!_usesPreferencesFallback) {
      await _purgeLegacyPlaintext();
      try {
        final value = await _storage.read(key: key);
        return (value == null || value.isEmpty) ? null : value;
      } catch (_) {
        return null;
      }
    }

    try {
      final secureValue = await _storage.read(key: key);

      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (_) {
      // Some web/browser contexts can reject secure storage reads after reload.
    }

    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  /// One-time cleanup of plaintext token copies written by older versions.
  Future<void> _purgeLegacyPlaintext() async {
    if (_legacyPurged) {
      return;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([for (final key in _keys) preferences.remove(key)]);
      _legacyPurged = true;
    } catch (_) {
      // Best effort; retried on the next call.
    }
  }

  Future<void> _trySecureWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // SharedPreferences is the durable fallback for web reload sessions.
    }
  }

  Future<void> _trySecureDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // The preference copy has already been cleared.
    }
  }
}
