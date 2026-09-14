// ignore_for_file: prefer_initializing_formals

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// dart.library.js_interop (not dart.library.html) is the WASM-compatible
// guard: dart:html is unavailable under dart2wasm, so gating on it would
// route WASM web builds to the in-memory stub instead of sessionStorage.
import 'session_token_store_stub.dart'
    if (dart.library.js_interop) 'session_token_store_web.dart'
    as session_store;

/// Mirrors the mobile app's TokenStorageService: writes to both secure
/// storage and SharedPreferences (the durable fallback for web reloads,
/// where secure storage can reject reads in some browser contexts).
///
/// Two tiers, chosen by [saveTokens]'s `persistent` flag:
///
/// * persistent ("keep me signed in" checked): secure storage +
///   SharedPreferences, survives closing the browser / app.
/// * session ("keep me signed in" unchecked): browser `sessionStorage` on
///   web (survives refresh, dies with the tab), process memory elsewhere.
///
/// Readers never need to know which tier was used — [getAccessToken] and
/// [getRefreshToken] check the persistent tier first, then the session
/// tier. Saving into one tier wipes the other so a stale pair from an
/// earlier login can never shadow the current one.
class TokenStorageService {
  const TokenStorageService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _accessTokenKey = 'admin_access_token';
  static const _refreshTokenKey = 'admin_refresh_token';
  static const _accessTokenExpiresAtKey = 'admin_access_token_expires_at';

  static const _allKeys = [
    _accessTokenKey,
    _refreshTokenKey,
    _accessTokenExpiresAtKey,
  ];

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
    bool persistent = true,
  }) async {
    final expiresAt = accessTokenExpiresAt.toUtc().toIso8601String();

    if (!persistent) {
      await _clearPersistent();
      session_store.writeSessionValue(_accessTokenKey, accessToken);
      session_store.writeSessionValue(_refreshTokenKey, refreshToken);
      session_store.writeSessionValue(_accessTokenExpiresAtKey, expiresAt);
      return;
    }

    _clearSession();

    final preferences = await SharedPreferences.getInstance();

    await Future.wait([
      preferences.setString(_accessTokenKey, accessToken),
      preferences.setString(_refreshTokenKey, refreshToken),
      preferences.setString(_accessTokenExpiresAtKey, expiresAt),
    ]);

    await _trySecureWrite(_accessTokenKey, accessToken);
    await _trySecureWrite(_refreshTokenKey, refreshToken);
    await _trySecureWrite(_accessTokenExpiresAtKey, expiresAt);
  }

  Future<String?> getAccessToken() => _readToken(_accessTokenKey);

  Future<String?> getRefreshToken() => _readToken(_refreshTokenKey);

  /// True when the current tokens came from the persistent tier, i.e. the
  /// admin chose "keep me signed in". Lets a token refresh land in the same
  /// tier the login used, so an unchecked box never silently upgrades to a
  /// durable session.
  Future<bool> isPersistent() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_accessTokenKey);
    return value != null && value.isNotEmpty;
  }

  Future<void> clearTokens() async {
    _clearSession();
    await _clearPersistent();
  }

  Future<String?> _readToken(String key) async {
    try {
      final secureValue = await _storage.read(key: key);

      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (_) {
      // Some web/browser contexts can reject secure storage reads after reload.
    }

    final preferences = await SharedPreferences.getInstance();
    final preferenceValue = preferences.getString(key);
    if (preferenceValue != null && preferenceValue.isNotEmpty) {
      return preferenceValue;
    }

    return session_store.readSessionValue(key);
  }

  void _clearSession() {
    for (final key in _allKeys) {
      session_store.removeSessionValue(key);
    }
  }

  Future<void> _clearPersistent() async {
    final preferences = await SharedPreferences.getInstance();

    await Future.wait([
      for (final key in _allKeys) preferences.remove(key),
    ]);

    for (final key in _allKeys) {
      await _trySecureDelete(key);
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
