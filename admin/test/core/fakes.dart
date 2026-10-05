import 'dart:convert';

import 'package:smartmoney_admin/core/auth/auth_api_service.dart';
import 'package:smartmoney_admin/core/auth/forgot_password_request.dart';
import 'package:smartmoney_admin/core/auth/forgot_password_response.dart';
import 'package:smartmoney_admin/core/auth/login_response.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/reset_password_request.dart';
import 'package:smartmoney_admin/core/auth/reset_password_response.dart';
import 'package:smartmoney_admin/core/auth/token_storage_service.dart';

/// Builds an unsigned JWT with the given role and expiry.
String fakeJwt({String? role, required DateTime expiresAt}) {
  String b64(Map<String, Object?> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');

  return [
    b64({'alg': 'none', 'typ': 'JWT'}),
    b64({
      'sub': 'user-1',
      'role': ?role,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    }),
    'sig',
  ].join('.');
}

class FakeTokenStorage implements TokenStorageService {
  FakeTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
  int clearCount = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> isPersistent() async => true;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
    bool persistent = true,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    clearCount++;
    accessToken = null;
    refreshToken = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthApi implements AuthApiService {
  FakeAuthApi(this.onRefresh);

  Future<RefreshTokenResponse> Function(String refreshToken) onRefresh;
  int refreshCalls = 0;

  @override
  String get baseUrl => 'https://example.test';

  @override
  Future<RefreshTokenResponse> refreshToken(String refreshToken) {
    refreshCalls++;
    return onRefresh(refreshToken);
  }

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<LoginResponse> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<ForgotPasswordResponse> forgotPassword(
    ForgotPasswordRequest request,
  ) => throw UnimplementedError();

  @override
  Future<ResetPasswordResponse> resetPassword(ResetPasswordRequest request) =>
      throw UnimplementedError();

  @override
  void dispose() {}
}
