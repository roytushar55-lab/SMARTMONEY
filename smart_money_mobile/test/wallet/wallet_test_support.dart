import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_money_mobile/core/network/authorized_api_client.dart';
import 'package:smart_money_mobile/features/auth/data/services/token_storage_service.dart';
import 'package:smart_money_mobile/features/wallet/data/services/wallet_api_service.dart';

/// In-memory [TokenStorageService] holding a signed-in user's tokens, so
/// requests carry a bearer header and never hit the real secure storage.
class FakeTokenStorage implements TokenStorageService {
  @override
  Future<String?> getAccessToken() async => 'access-token';

  @override
  Future<String?> getRefreshToken() async => 'refresh-token';

  @override
  Future<DateTime?> getAccessTokenExpiresAt() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
  }) async {}

  @override
  Future<void> clearTokens() async {}
}

/// The wallet summary as `GET /api/wallet` returns it.
Map<String, dynamic> walletJson({
  double available = 1250.5,
  double pending = 300,
  double held = 0,
  double earned = 4000,
  double withdrawn = 2449.5,
}) => {
  'availableBalance': available,
  'pendingBalance': pending,
  'heldBalance': held,
  'totalEarned': earned,
  'totalWithdrawn': withdrawn,
};

/// One ledger row as `GET /api/wallet/transactions` returns it.
Map<String, dynamic> transactionJson(
  String type, {
  double amount = 500,
  String? description,
  String id = 't1',
}) => {
  'id': id,
  'type': type,
  'amount': amount,
  'description': description,
  'availableBalanceAfter': 0,
  'pendingBalanceAfter': 0,
  'createdAt': '2026-10-11T12:30:00Z',
};

/// A [WalletApiService] answering from [wallet] and [transactions].
WalletApiService fakeWalletService({
  required Map<String, dynamic> wallet,
  List<Map<String, dynamic>> transactions = const [],
  void Function(http.Request request)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request);
    final body = request.url.path == '/api/wallet'
        ? wallet
        : {'items': transactions, 'totalCount': transactions.length};
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  return WalletApiService(
    client: AuthorizedApiClient(
      client: client,
      tokenStorageService: FakeTokenStorage(),
      baseUrl: 'http://test.local',
    ),
  );
}
