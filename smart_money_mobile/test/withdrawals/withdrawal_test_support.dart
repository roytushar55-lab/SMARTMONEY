import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_money_mobile/core/network/authorized_api_client.dart';
import 'package:smart_money_mobile/features/withdrawals/data/services/withdrawal_api_service.dart';

import '../wallet/wallet_test_support.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// `GET /api/withdrawals/preview` as the backend answers it for [amount].
Map<String, dynamic> previewJson({
  double amount = 0,
  double available = 800,
  double minimum = 250,
  double maximum = 50000,
  double userFee = 0,
  bool? canWithdraw,
  String? message,
}) {
  final allowed = canWithdraw ?? (amount >= minimum && amount <= available);
  return {
    'amount': amount,
    'feeTotal': userFee * 2,
    'userFee': userFee,
    'netAmount': amount - userFee,
    'userFeeSharePercent': 50,
    'minimumAmount': minimum,
    'maximumAmount': maximum,
    'availableBalance': available,
    'canWithdraw': allowed,
    'message': allowed
        ? null
        : (message ?? 'Your available balance is lower than this amount.'),
  };
}

/// `WithdrawalResponse` for a freshly requested UPI withdrawal.
Map<String, dynamic> withdrawalJson({
  double amount = 500,
  double userFee = 0,
  String status = 'Requested',
  String destination = 'te****@okhdfc',
  String? failureReason,
  bool? canCancel,
  String id = '11111111-1111-1111-1111-111111111111',
}) => {
  'id': id,
  'reference': 'WD20261011K7QM2XA9PD',
  'amount': amount,
  'feeTotal': userFee * 2,
  'userFee': userFee,
  'netAmount': amount - userFee,
  'method': 'Upi',
  'destination': destination,
  'status': status,
  'failureReason': failureReason,
  'transactionReference': null,
  'canCancel': canCancel ?? status == 'Requested',
  'requestedAt': '2026-10-11T12:30:57Z',
  'settledAt': null,
};

/// `WithdrawalListResponse` for [items].
Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> items, {
  int? totalCount,
  int page = 1,
  int pageSize = 20,
}) => {
  'items': items,
  'totalCount': totalCount ?? items.length,
  'page': page,
  'pageSize': pageSize,
};

/// `WithdrawalDecisionResponse` after a cancel.
Map<String, dynamic> decisionJson({
  String id = '11111111-1111-1111-1111-111111111111',
  String status = 'Cancelled',
  double available = 1300,
}) => {
  'withdrawalId': id,
  'reference': 'WD20261011K7QM2XA9PD',
  'status': status,
  'availableBalance': available,
  'heldBalance': 0,
};

/// A [WithdrawalApiService] wired to a fake server, every request recorded.
class FakeWithdrawalServer {
  FakeWithdrawalServer(this.respond) {
    service = WithdrawalApiService(
      client: AuthorizedApiClient(
        client: MockClient((request) {
          seen.add(request);
          return respond(request);
        }),
        tokenStorageService: FakeTokenStorage(),
        baseUrl: 'http://test.local',
      ),
    );
  }

  /// Decides each response; a test may swap it between requests.
  Future<http.Response> Function(http.Request request) respond;

  final List<http.Request> seen = [];
  late final WithdrawalApiService service;

  List<http.Request> get previews => seen
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/preview'))
      .toList();

  List<http.Request> get posts =>
      seen.where((r) => r.method == 'POST').toList();

  /// Answers previews from [previewJson] with the asked amount, and posts
  /// with [onPost] (a 201 with [withdrawalJson] by default).
  static FakeWithdrawalServer standard({
    double available = 800,
    double userFee = 0,
    Future<http.Response> Function(http.Request request)? onPost,
  }) {
    return FakeWithdrawalServer((request) async {
      if (request.method == 'POST') {
        if (onPost != null) return onPost(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(
          withdrawalJson(
            amount: (body['amount'] as num).toDouble(),
            userFee: userFee,
          ),
          201,
        );
      }
      final amount =
          double.tryParse(request.url.queryParameters['amount'] ?? '') ?? 0;
      return jsonResponse(
        previewJson(amount: amount, available: available, userFee: userFee),
      );
    });
  }
}
