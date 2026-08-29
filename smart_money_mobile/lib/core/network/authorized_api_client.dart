// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/data/models/refresh_token_request.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/data/services/token_storage_service.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Shared HTTP helper for endpoints that require a bearer token.
///
/// Attaches the stored access token, and on a 401 refreshes it once via
/// `/api/identity/refresh-token` and retries — the same pattern
/// `ProfileApiService` uses, generalized so new authorized services (wallet,
/// cashbacks, ...) don't reimplement it.
class AuthorizedApiClient {
  AuthorizedApiClient({
    http.Client? client,
    TokenStorageService tokenStorageService = const TokenStorageService(),
    AuthApiService? authApiService,
    this.baseUrl = ApiConfig.baseUrl,
  }) : _client = client ?? http.Client(),
       _tokenStorageService = tokenStorageService,
       _authApiService = authApiService ?? AuthApiService(baseUrl: baseUrl),
       _ownsAuthApiService = authApiService == null;

  final http.Client _client;
  final TokenStorageService _tokenStorageService;
  final AuthApiService _authApiService;
  final bool _ownsAuthApiService;
  final String baseUrl;

  static const String signInMessage = 'Sign in to continue.';
  static const String sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await get(path);
    return _decodeMap(response);
  }

  Future<http.Response> get(String path) {
    return sendAuthorizedRequest(
      (headers) => _client.get(Uri.parse('$baseUrl$path'), headers: headers),
    );
  }

  Future<http.Response> post(String path, {Object? body}) {
    return sendAuthorizedRequest(
      (headers) => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response, 'Something went wrong. Please try again.'),
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid response.');
    }
    return decoded;
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // Falls through to the generic message below.
    }
    return fallback;
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await _tokenStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(signInMessage, statusCode: 401);
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> sendAuthorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final response = await send(await _authorizedHeaders());

    if (response.statusCode != 401) {
      return response;
    }

    final refreshed = await _refreshAccessToken();

    if (!refreshed) {
      throw const ApiException(sessionExpiredMessage, statusCode: 401);
    }

    return send(await _authorizedHeaders());
  }

  Future<bool> _refreshAccessToken() async {
    final storedRefreshToken = await _tokenStorageService.getRefreshToken();

    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _authApiService.refreshToken(
        RefreshTokenRequest(refreshToken: storedRefreshToken),
      );

      await _tokenStorageService.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        accessTokenExpiresAt: response.accessTokenExpiresAt,
      );

      return true;
    } catch (_) {
      await _tokenStorageService.clearTokens();
      return false;
    }
  }

  void dispose() {
    _client.close();
    if (_ownsAuthApiService) {
      _authApiService.dispose();
    }
  }
}
