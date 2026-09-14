import 'package:flutter/foundation.dart';

import 'auth_api_service.dart';
import 'jwt_claims.dart';
import 'token_storage_service.dart';

/// App-wide singleton holding the signed-in admin's identity. `claims` is
/// null when signed out; screens and the shell read it via
/// [ValueListenableBuilder] rather than re-fetching per widget.
class AdminSession {
  AdminSession._();

  static final AdminSession instance = AdminSession._();

  final ValueNotifier<JwtClaims?> claims = ValueNotifier<JwtClaims?>(null);

  final TokenStorageService _tokenStorage = const TokenStorageService();
  final AuthApiService _authApi = AuthApiService();

  bool _restored = false;

  /// Restores a session from stored tokens on app start. Safe to call more
  /// than once; only does work the first time.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;

    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final parsed = JwtClaims.tryParse(token);
    if (parsed != null) {
      claims.value = parsed;
    }
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
    await _tokenStorage.clearTokens();
    claims.value = null;
  }
}
