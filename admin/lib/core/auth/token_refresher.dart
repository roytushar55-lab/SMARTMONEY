// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../network/api_exception.dart';
import 'auth_api_service.dart';
import 'token_storage_service.dart';

enum RefreshResult {
  /// New tokens were saved; callers should retry with the new access token.
  refreshed,

  /// The server definitively rejected the refresh token (or none is stored).
  /// Tokens were cleared and [TokenRefresher.onSessionExpired] fired.
  sessionExpired,

  /// Network error, timeout or 5xx. Tokens are untouched; the session may
  /// still be valid, so the caller should just report a connectivity error.
  unavailable,
}

/// Refreshes the access token with a single-flight guarantee: concurrent
/// callers share one in-flight request. That matters because refresh tokens
/// rotate — a second parallel refresh with the already-spent token would be
/// rejected and wrongly sign the admin out.
class TokenRefresher {
  TokenRefresher({
    TokenStorageService tokenStorage = const TokenStorageService(),
    AuthApiService? authApi,
    this.onSessionExpired,
    this.onTokensRefreshed,
  }) : _tokenStorage = tokenStorage,
       _authApi = authApi ?? AuthApiService();

  /// Shared by every [AuthorizedApiClient] so all services coordinate.
  static final TokenRefresher shared = TokenRefresher();

  final TokenStorageService _tokenStorage;
  final AuthApiService _authApi;

  /// Fired after a definitive refresh failure (the UI should return to login).
  FutureOr<void> Function()? onSessionExpired;

  /// Fired with the new access token after every successful refresh.
  FutureOr<void> Function(String accessToken)? onTokensRefreshed;

  Future<RefreshResult>? _inFlight;

  Future<RefreshResult> refresh() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<RefreshResult> _run() async {
    final storedRefreshToken = await _tokenStorage.getRefreshToken();

    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      await _expire();
      return RefreshResult.sessionExpired;
    }

    // Decide the tier BEFORE the network call: the refresh lands in the same
    // tier the login used, so an unchecked "keep me signed in" never gets
    // silently upgraded to a durable session by a routine token refresh.
    final persistent = await _tokenStorage.isPersistent();

    try {
      final response = await _authApi.refreshToken(storedRefreshToken);

      // The admin may have signed out while the request was in flight;
      // never resurrect a cleared session.
      final current = await _tokenStorage.getRefreshToken();
      if (current != storedRefreshToken) {
        return RefreshResult.sessionExpired;
      }

      if (response.accessToken.isEmpty || response.refreshToken.isEmpty) {
        return RefreshResult.unavailable;
      }

      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        accessTokenExpiresAt: response.accessTokenExpiresAt,
        persistent: persistent,
      );

      await onTokensRefreshed?.call(response.accessToken);

      return RefreshResult.refreshed;
    } on ApiException catch (error) {
      if (isDefinitiveRefreshFailure(error.statusCode)) {
        await _expire();
        return RefreshResult.sessionExpired;
      }
      return RefreshResult.unavailable;
    } catch (_) {
      return RefreshResult.unavailable;
    }
  }

  Future<void> _expire() async {
    await _tokenStorage.clearTokens();
    await onSessionExpired?.call();
  }

  /// The server answered and rejected the refresh token (as opposed to being
  /// unreachable or failing with a 5xx).
  static bool isDefinitiveRefreshFailure(int? statusCode) =>
      statusCode == 400 || statusCode == 401 || statusCode == 403;
}
