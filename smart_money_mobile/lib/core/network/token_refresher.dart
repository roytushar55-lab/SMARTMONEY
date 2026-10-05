import 'dart:async';

import '../../features/auth/data/models/refresh_token_request.dart';
import '../../features/auth/data/models/refresh_token_response.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/data/services/token_storage_service.dart';
import 'api_exception.dart';

/// Result of a refresh attempt.
enum RefreshOutcome {
  /// New tokens were obtained and saved.
  refreshed,

  /// The server definitively rejected the refresh token (or none is stored);
  /// stored tokens have been cleared and the user must sign in again.
  rejected,

  /// Network error, timeout or server error. Tokens are kept so the caller
  /// can surface a retryable error instead of logging the user out.
  transientFailure,
}

/// The single shared refresh implementation. Concurrent callers (for example
/// several requests that all hit a 401 together) await ONE in-flight request,
/// which matters because refresh tokens rotate: a second concurrent refresh
/// would present an already-used token and get the session revoked.
class TokenRefresher {
  TokenRefresher._();

  static Completer<RefreshOutcome>? _inFlight;

  static Future<RefreshOutcome> refresh({
    required TokenStorageService tokenStorage,
    required AuthApiService authApi,
  }) {
    return refreshWith(
      tokenStorage: tokenStorage,
      requestRefresh: (token) =>
          authApi.refreshToken(RefreshTokenRequest(refreshToken: token)),
    );
  }

  /// Same as [refresh] with the HTTP call injected (used by tests).
  static Future<RefreshOutcome> refreshWith({
    required TokenStorageService tokenStorage,
    required Future<RefreshTokenResponse> Function(String refreshToken)
    requestRefresh,
  }) {
    final existing = _inFlight;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<RefreshOutcome>();
    _inFlight = completer;

    _run(tokenStorage, requestRefresh)
        .then(completer.complete)
        .catchError((Object _) {
          completer.complete(RefreshOutcome.transientFailure);
        })
        .whenComplete(() {
          _inFlight = null;
        });

    return completer.future;
  }

  static Future<RefreshOutcome> _run(
    TokenStorageService tokenStorage,
    Future<RefreshTokenResponse> Function(String refreshToken) requestRefresh,
  ) async {
    final storedRefreshToken = await tokenStorage.getRefreshToken();

    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      await tokenStorage.clearTokens();
      return RefreshOutcome.rejected;
    }

    final RefreshTokenResponse response;
    try {
      response = await requestRefresh(storedRefreshToken);
    } on ApiException catch (error) {
      if (_isDefinitiveRejection(error.statusCode)) {
        await tokenStorage.clearTokens();
        return RefreshOutcome.rejected;
      }
      return RefreshOutcome.transientFailure;
    } catch (_) {
      return RefreshOutcome.transientFailure;
    }

    await tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      accessTokenExpiresAt: response.accessTokenExpiresAt,
    );

    return RefreshOutcome.refreshed;
  }

  static bool _isDefinitiveRejection(int? statusCode) =>
      statusCode == 400 || statusCode == 401 || statusCode == 403;
}
