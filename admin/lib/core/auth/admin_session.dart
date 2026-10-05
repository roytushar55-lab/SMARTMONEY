// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'auth_api_service.dart';
import 'jwt_claims.dart';
import 'token_refresher.dart';
import 'token_storage_service.dart';

/// App-wide singleton holding the signed-in admin's identity. `claims` is
/// null when signed out; screens and the shell read it via
/// [ValueListenableBuilder] rather than re-fetching per widget.
///
/// Role checks against `claims` only decide which screens to show; the
/// server enforces authorization on every request.
class AdminSession {
  AdminSession({
    TokenStorageService tokenStorage = const TokenStorageService(),
    AuthApiService? authApi,
    TokenRefresher? refresher,
    DateTime Function()? now,
  }) : _tokenStorage = tokenStorage,
       _authApi = authApi ?? AuthApiService(),
       _refresher = refresher ?? TokenRefresher.shared,
       _now = now ?? DateTime.now {
    // A definitive refresh failure signs the admin out of the UI, and every
    // successful refresh re-reads the role from the new access token so a
    // demoted admin loses SuperAdmin-only menu items without a reload.
    _refresher.onSessionExpired = _handleSessionExpired;
    _refresher.onTokensRefreshed = _applyAccessToken;
  }

  static final AdminSession instance = AdminSession();

  final ValueNotifier<JwtClaims?> claims = ValueNotifier<JwtClaims?>(null);

  final TokenStorageService _tokenStorage;
  final AuthApiService _authApi;
  final TokenRefresher _refresher;
  final DateTime Function() _now;

  /// Access tokens within this window of expiry are treated as expired.
  static const Duration _expirySkew = Duration(seconds: 30);

  bool _restored = false;

  /// Restores a session from stored tokens on app start. Safe to call more
  /// than once; only does work the first time.
  ///
  /// A stored token is accepted only if it is unexpired and carries an
  /// Admin/SuperAdmin role. An expired token is exchanged via the refresh
  /// token; if that is impossible the stored tokens are cleared and the
  /// login screen is shown.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;

    final token = await _tokenStorage.getAccessToken();
    final hasToken = token != null && token.isNotEmpty;
    final parsed = hasToken ? JwtClaims.tryParse(token) : null;

    if (hasToken && parsed == null) {
      // Unparseable token: nothing usable is stored.
      await logout();
      return;
    }

    if (parsed != null && !parsed.isAdminOrAbove) {
      await logout();
      return;
    }

    final expiresAt = parsed?.expiresAt;
    final isFresh =
        parsed != null &&
        expiresAt != null &&
        expiresAt.isAfter(_now().toUtc().add(_expirySkew));

    if (isFresh) {
      claims.value = parsed;
      return;
    }

    // Expired (or no access token): only a successful refresh can restore
    // the session. The refresher's hooks set or clear [claims]. If the server
    // is merely unreachable we stay signed out but keep the tokens, so a
    // later reload can retry.
    await _refresher.refresh();
  }

  Future<void> _handleSessionExpired() async {
    await _tokenStorage.clearTokens();
    claims.value = null;
  }

  Future<void> _applyAccessToken(String accessToken) async {
    final parsed = JwtClaims.tryParse(accessToken);

    if (parsed == null || !parsed.isAdminOrAbove) {
      // Demoted (or malformed): don't keep the admin UI open.
      await logout();
      return;
    }

    claims.value = parsed;
  }

  /// Throws on failure (invalid credentials, network error) — the login
  /// screen surfaces the message. Throws a plain [StateError] when the
  /// account authenticates but isn't Admin/SuperAdmin, since that's a
  /// business rule this app enforces, not a network failure.
  ///
  /// [rememberMe] only chooses where the tokens live. Checked: durable
  /// storage that survives closing the browser/app. Unchecked: the session
  /// tier (browser `sessionStorage`, or memory on native), which survives a
  /// page refresh but is gone once the tab closes. Tokens are always saved,
  /// because every authorized request reads them back through
  /// [TokenStorageService] — an unsaved login would look signed in while
  /// every API call failed with 401.
  Future<void> login(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    final response = await _authApi.login(email, password);

    final parsed = JwtClaims.tryParse(response.accessToken);
    if (parsed == null || !parsed.isAdminOrAbove) {
      throw StateError('This account does not have admin access.');
    }

    await _tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      accessTokenExpiresAt: response.accessTokenExpiresAt,
      persistent: rememberMe,
    );

    claims.value = parsed;
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _authApi.logout(refreshToken);
    }

    await _tokenStorage.clearTokens();
    claims.value = null;
  }
}
