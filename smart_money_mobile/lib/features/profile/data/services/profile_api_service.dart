// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/token_refresher.dart';
import '../../../auth/data/services/auth_api_service.dart';
import '../../../auth/data/services/token_storage_service.dart';
import '../models/profile_response.dart';

class ProfileApiService {
  ProfileApiService({
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

  static const String _signInMessage = 'Sign in to view your profile.';
  static const String _sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  Future<ProfileResponse> getProfile() async {
    final response = await _sendAuthorizedRequest(
      (headers) =>
          _client.get(Uri.parse('$baseUrl/api/profile'), headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Profile load failed. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response.');
    }

    return ProfileResponse.fromJson(decodedBody);
  }

  Future<ProfileResponse> updateName(String name) async {
    final response = await _sendAuthorizedRequest(
      (headers) => _client.put(
        Uri.parse('$baseUrl/api/profile/update-name'),
        headers: headers,
        body: jsonEncode({'name': name}),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Name update failed. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response.');
    }

    return ProfileResponse.fromJson(decodedBody);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _sendAuthorizedRequest(
      (headers) => _client.put(
        Uri.parse('$baseUrl/api/profile/change-password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(response, 'Password update failed. Please try again.'),
        statusCode: response.statusCode,
      );
    }
  }

  /// Permanently deletes the signed-in account after re-checking the
  /// password. The backend answers 400 for a wrong password and 409 while
  /// the wallet still holds withdrawable money; both carry a user-safe
  /// `message`, which is surfaced as the [ApiException] message.
  Future<void> deleteAccount(String password) async {
    final response = await _sendAuthorizedRequest(
      (headers) => _client.post(
        Uri.parse('$baseUrl/api/profile/delete-account'),
        headers: headers,
        body: jsonEncode({'password': password}),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(
          response,
          'Unable to delete your account. Please try again.',
        ),
        statusCode: response.statusCode,
      );
    }
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall through to the generic message.
    }
    return fallback;
  }

  Future<ProfileResponse> uploadProfilePhoto({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final response = await _sendAuthorizedRequest((headers) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/profile/photo'),
      );

      request.headers['Authorization'] = headers['Authorization'] ?? '';
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );

      final streamedResponse = await _client.send(request);
      return http.Response.fromStream(streamedResponse);
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Profile photo upload failed. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response.');
    }

    return ProfileResponse.fromJson(decodedBody);
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await _tokenStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(_signInMessage, statusCode: 401);
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _sendAuthorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final response = await guardNetwork(
      () async => send(await _authorizedHeaders()),
    );

    if (response.statusCode != 401) {
      return response;
    }

    final outcome = await TokenRefresher.refresh(
      tokenStorage: _tokenStorageService,
      authApi: _authApiService,
    );

    switch (outcome) {
      case RefreshOutcome.refreshed:
        return guardNetwork(() async => send(await _authorizedHeaders()));
      case RefreshOutcome.rejected:
        // Distinguishes "session is truly dead" (revoked/expired refresh
        // token) from any other failure, so callers can prompt a re-login
        // instead of showing a generic, unexplained error.
        throw const ApiException(_sessionExpiredMessage, statusCode: 401);
      case RefreshOutcome.transientFailure:
        throw const ApiException(kNetworkErrorMessage);
    }
  }

  void dispose() {
    _client.close();

    if (_ownsAuthApiService) {
      _authApiService.dispose();
    }
  }
}
