import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';
import 'package:smartmoney_admin/features/withdrawals/services/admin_withdrawal_api_service.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawal_queues.dart';

import '../../core/fakes.dart';

/// A withdrawal as the backend returns it in a list: a freshly requested UPI
/// withdrawal with nothing else having happened yet. Pass [overrides] to turn
/// it into any other state.
Map<String, dynamic> withdrawalRow([Map<String, dynamic>? overrides]) => {
  'id': '11111111-1111-1111-1111-111111111111',
  'reference': 'WD20261011K7QM2XA9PD',
  'userId': '22222222-2222-2222-2222-222222222222',
  'userFullName': 'Withdraw Test User',
  'userEmail': 'wd-user-1011@example.com',
  'amount': 500,
  'feeTotal': 11.8,
  'userFee': 5.9,
  'netAmount': 494.1,
  'method': 'Upi',
  'destinationMasked': 'te****@okhdfc',
  'status': 'Requested',
  'providerName': null,
  'providerReference': null,
  'actualProviderFee': null,
  'failureReason': null,
  'lastError': null,
  'submissionAttempts': 0,
  'reviewedByUserId': null,
  'reviewNote': null,
  'needsAttention': false,
  'requestedAt': '2026-10-11T12:30:57.9942456Z',
  'approvedAt': null,
  'submittedAt': null,
  'settledAt': null,
  'destination': null,
  'destinationUnreadable': false,
  ...?overrides,
};

Map<String, dynamic> withdrawalPage(
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

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// An [AdminWithdrawalApiService] wired to a fake server, with every request
/// it receives recorded in [seen].
class FakeWithdrawalServer {
  FakeWithdrawalServer(this.respond) {
    final storage = FakeTokenStorage(accessToken: 'tok', refreshToken: 'r1');
    final refresher = TokenRefresher(
      tokenStorage: storage,
      authApi: FakeAuthApi(
        (_) async => RefreshTokenResponse(
          accessToken: 'new',
          accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'r2',
        ),
      ),
      onSessionExpired: () {},
      onTokensRefreshed: (_) {},
    );

    service = AdminWithdrawalApiService(
      client: AuthorizedApiClient(
        client: MockClient((request) {
          seen.add(request);
          return respond(request);
        }),
        tokenStorageService: storage,
        refresher: refresher,
        baseUrl: 'https://example.test',
        timeout: const Duration(seconds: 5),
      ),
    );
  }

  /// Decides each response; may be swapped between requests by a test.
  Future<http.Response> Function(http.Request request) respond;

  final List<http.Request> seen = [];
  late final AdminWithdrawalApiService service;

  /// The query string of the n-th request, for example
  /// `page=1&pageSize=20&status=Requested`.
  String query(int index) => seen[index].url.query;
}

/// Opens the tab that holds a withdrawal in [status] (To decide is the default
/// tab, so nothing to do for Requested). For tests that start from the list.
Future<void> openTabFor(WidgetTester tester, String status) async {
  final queue = WithdrawalQueue.forStatus(status);
  if (queue == WithdrawalQueue.toDecide) return;

  // The tab row scrolls sideways in a narrow test window.
  final tab = find.byKey(ValueKey('queue-tab-${queue.apiName}'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}
