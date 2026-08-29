import 'dart:convert';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/authorized_api_client.dart';
import '../models/cashback_item.dart';

class CashbackApiService {
  CashbackApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<List<CashbackItem>> getMyCashbacks({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.get(
      '/api/cashbacks?page=$page&pageSize=$pageSize',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Unable to load your cashback. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      throw const FormatException('Invalid cashbacks response.');
    }

    return (decoded['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(CashbackItem.fromJson)
        .toList();
  }

  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }
}
