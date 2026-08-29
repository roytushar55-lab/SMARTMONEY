import 'dart:convert';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/authorized_api_client.dart';
import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';

class WalletApiService {
  WalletApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  Future<WalletSummary> getMyWallet() async {
    final json = await _client.getJson('/api/wallet');
    return WalletSummary.fromJson(json);
  }

  /// Returns one page of the wallet ledger, newest first per the backend's
  /// default ordering.
  Future<List<WalletTransaction>> getMyTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.get(
      '/api/wallet/transactions?page=$page&pageSize=$pageSize',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Unable to load your transactions. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      throw const FormatException('Invalid wallet transactions response.');
    }

    return (decoded['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(WalletTransaction.fromJson)
        .toList();
  }

  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }
}
