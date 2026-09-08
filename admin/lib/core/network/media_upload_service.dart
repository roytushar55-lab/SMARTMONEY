// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../auth/token_storage_service.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Wraps `POST /api/admin/media/upload` (multipart) — separate from
/// [AuthorizedApiClient] because that helper only speaks JSON bodies.
class MediaUploadService {
  MediaUploadService({
    http.Client? client,
    TokenStorageService tokenStorageService = const TokenStorageService(),
    this.baseUrl = ApiConfig.baseUrl,
  }) : _client = client ?? http.Client(),
       _tokenStorageService = tokenStorageService;

  final http.Client _client;
  final TokenStorageService _tokenStorageService;
  final String baseUrl;

  /// [folder] is one of "stores", "offers", "categories" — anything else
  /// falls back to a flat "misc" prefix on the backend. Returns the public URL.
  Future<String> upload({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String folder,
  }) async {
    final token = await _tokenStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Sign in to continue.',
        statusCode: 401,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/admin/media/upload'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: _parseContentType(contentType),
        ),
      );


    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response, 'Image upload failed.'),
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['url'] is! String) {
      throw const FormatException('Invalid upload response.');
    }

    return decoded['url'] as String;
  }

  MediaType? _parseContentType(String contentType) {
    try {
      return MediaType.parse(contentType);
    } catch (_) {
      return null;
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

  void dispose() => _client.close();
}
