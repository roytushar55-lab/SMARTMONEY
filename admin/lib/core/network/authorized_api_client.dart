// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/token_refresher.dart';
import '../auth/token_storage_service.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'network_errors.dart';

/// Shared HTTP helper for admin endpoints: attaches the stored access token,
/// and on a 401 refreshes it once (single-flight, shared across every
/// request) via `/api/identity/refresh-token` and retries. Mirrors the mobile
/// app's AuthorizedApiClient.
///
/// Transport failures (no connection, timeout, malformed body) are converted
/// to [ApiException] with a user-safe message so screens never hang or show
/// raw exception text.
class AuthorizedApiClient {
  AuthorizedApiClient({
    http.Client? client,
    TokenStorageService tokenStorageService = const TokenStorageService(),
    TokenRefresher? refresher,
    this.baseUrl = ApiConfig.baseUrl,
    this.timeout = apiTimeout,
  }) : _client = client ?? http.Client(),
       _tokenStorageService = tokenStorageService,
       _refresher = refresher ?? TokenRefresher.shared;

  final http.Client _client;
  final TokenStorageService _tokenStorageService;
  final TokenRefresher _refresher;
  final String baseUrl;
  final Duration timeout;

  static const String signInMessage = 'Sign in to continue.';
  static const String sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  Future<dynamic> getJson(String path) async {
    final response = await get(path);
    return _decode(response);
  }

  Future<http.Response> get(String path) {
    return sendAuthorizedRequest(
      (headers) => _client.get(Uri.parse('$baseUrl$path'), headers: headers),
    );
  }

  Future<dynamic> postJson(String path, {Object? body}) async {
    final response = await post(path, body: body);
    return _decode(response);
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

  Future<dynamic> putJson(String path, {Object? body}) async {
    final response = await put(path, body: body);
    return _decode(response);
  }

  Future<http.Response> put(String path, {Object? body}) {
    return sendAuthorizedRequest(
      (headers) => _client.put(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<dynamic> deleteJson(String path) async {
    final response = await delete(path);
    return _decode(response);
  }

  Future<http.Response> delete(String path) {
    return sendAuthorizedRequest(
      (headers) =>
          _client.delete(Uri.parse('$baseUrl$path'), headers: headers),
    );
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(
          response,
          'Something went wrong. Please try again.',
        ),
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) return null;

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException(badResponseMessage);
    }
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

  Future<String> _accessToken() async {
    final token = await _tokenStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(signInMessage, statusCode: 401);
    }

    return token;
  }

  Map<String, String> _headersFor(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<http.Response> _guardedSend(
    Future<http.Response> Function(Map<String, String> headers) send,
    String token,
  ) {
    return guardNetwork(() => send(_headersFor(token)), timeout: timeout);
  }

  Future<http.Response> sendAuthorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final usedToken = await _accessToken();
    final response = await _guardedSend(send, usedToken);

    if (response.statusCode != 401) {
      return response;
    }

    // Another request may already have refreshed while this one was in
    // flight; if the stored token changed, just retry with it instead of
    // spending the (rotated) refresh token again.
    final currentToken = await _tokenStorageService.getAccessToken();
    final alreadyRefreshed =
        currentToken != null &&
        currentToken.isNotEmpty &&
        currentToken != usedToken;

    if (!alreadyRefreshed) {
      final result = await _refresher.refresh();

      switch (result) {
        case RefreshResult.refreshed:
          break;
        case RefreshResult.sessionExpired:
          throw const ApiException(sessionExpiredMessage, statusCode: 401);
        case RefreshResult.unavailable:
          throw const ApiException(networkErrorMessage);
      }
    }

    return _guardedSend(send, await _accessToken());
  }

  void dispose() {
    _client.close();
  }
}
