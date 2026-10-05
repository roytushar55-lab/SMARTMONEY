// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../../core/network/token_refresher.dart';
import 'auth_api_service.dart';
import 'token_storage_service.dart';

class AuthSessionService {
  // Keep the public parameter name stable for callers/tests.
  AuthSessionService({
    TokenStorageService tokenStorageService = const TokenStorageService(),
    AuthApiService? authApiService,
  }) : _tokenStorageService = tokenStorageService,
       _authApiService = authApiService ?? AuthApiService(),
       _ownsAuthApiService = authApiService == null;

  final TokenStorageService _tokenStorageService;
  final AuthApiService _authApiService;
  final bool _ownsAuthApiService;

  Future<bool> hasValidSession() async {
    try {
      final accessToken = await _tokenStorageService.getAccessToken();
      final accessTokenExpiresAt = await _tokenStorageService
          .getAccessTokenExpiresAt();

      if (accessToken != null &&
          accessToken.isNotEmpty &&
          accessTokenExpiresAt != null &&
          accessTokenExpiresAt.isAfter(
            DateTime.now().toUtc().add(const Duration(seconds: 30)),
          )) {
        return true;
      }

      final outcome = await TokenRefresher.refresh(
        tokenStorage: _tokenStorageService,
        authApi: _authApiService,
      );

      // A transient failure (offline, timeout, 5xx) keeps the stored
      // tokens, so the user stays signed in; later requests retry the
      // refresh and surface a retryable error instead of a logout.
      return outcome != RefreshOutcome.rejected;
    } catch (error) {
      debugPrint('TOKEN READ ERROR: $error');
      return false;
    }
  }

  void dispose() {
    if (_ownsAuthApiService) {
      _authApiService.dispose();
    }
  }
}
