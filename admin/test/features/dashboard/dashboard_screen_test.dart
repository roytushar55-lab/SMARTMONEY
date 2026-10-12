import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';
import 'package:smartmoney_admin/core/widgets/admin_stat_card.dart';
import 'package:smartmoney_admin/features/cashbacks/services/admin_cashback_api_service.dart';
import 'package:smartmoney_admin/features/dashboard/screens/dashboard_screen.dart';
import 'package:smartmoney_admin/features/users/services/admin_user_api_service.dart';
import 'package:smartmoney_admin/features/withdrawals/services/admin_withdrawal_api_service.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawals_filter.dart';

import '../../core/fakes.dart';
import '../withdrawals/withdrawal_test_support.dart';

/// Every admin endpoint the dashboard asks, answered from one fake server.
/// Cashback and user counts are all zero so the withdrawal numbers are the
/// only non-zero figures on the page.
class _FakeAdminApi {
  _FakeAdminApi({this.failWithdrawals = false}) {
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
    final client = AuthorizedApiClient(
      client: MockClient(_handle),
      tokenStorageService: storage,
      refresher: refresher,
      baseUrl: 'https://example.test',
      timeout: const Duration(seconds: 5),
    );
    cashbacks = AdminCashbackApiService(client: client);
    users = AdminUserApiService(client: client);
    withdrawals = AdminWithdrawalApiService(client: client);
  }

  static const needsAttention = 2;
  static const requested = 5;
  static const approved = 3;

  final bool failWithdrawals;

  late final AdminCashbackApiService cashbacks;
  late final AdminUserApiService users;
  late final AdminWithdrawalApiService withdrawals;

  final List<http.Request> seen = [];

  List<String> get withdrawalQueries => seen
      .where((r) => r.url.path == '/api/admin/withdrawals')
      .map((r) => r.url.query)
      .toList();

  Future<http.Response> _handle(http.Request request) async {
    seen.add(request);
    final path = request.url.path;
    final params = request.url.queryParameters;

    if (path == '/api/admin/users/stats') {
      return jsonResponse({
        'totalUsers': 0,
        'activeUsers': 0,
        'deactivatedUsers': 0,
        'deletedUsers': 0,
        'newThisWeek': 0,
      });
    }
    if (path == '/api/admin/cashbacks') {
      return jsonResponse({
        'items': <Object>[],
        'totalCount': 0,
        'page': 1,
        'pageSize': 1,
      });
    }
    if (path == '/api/admin/withdrawals') {
      if (failWithdrawals) {
        return jsonResponse({'message': 'Withdrawals are unavailable.'}, 500);
      }
      final count = params['needsAttention'] == 'true'
          ? needsAttention
          : params['status'] == 'Requested'
          ? requested
          : params['status'] == 'Approved'
          ? approved
          : 0;
      return jsonResponse(withdrawalPage([], totalCount: count, pageSize: 1));
    }
    return jsonResponse({'message': 'Unexpected request: $path'}, 404);
  }
}

Future<List<WithdrawalsFilter>> _pump(
  WidgetTester tester,
  _FakeAdminApi api,
) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final opened = <WithdrawalsFilter>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardScreen(
          onOpenReviewQueue: (_) {},
          onOpenWithdrawals: opened.add,
          cashbackService: api.cashbacks,
          userService: api.users,
          withdrawalService: api.withdrawals,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Finder _card(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(AdminStatCard));

String _cardValue(WidgetTester tester, String label) =>
    tester.widget<AdminStatCard>(_card(label)).value;

void main() {
  testWidgets('shows how many withdrawals need an admin', (tester) async {
    final api = _FakeAdminApi();

    await _pump(tester, api);

    expect(_cardValue(tester, 'Needs attention'), '2');
    expect(_cardValue(tester, 'Waiting for approval'), '5');
    expect(_cardValue(tester, 'Approved, not yet paid'), '3');

    // Counts only: one row per request.
    expect(
      api.withdrawalQueries,
      unorderedEquals([
        'page=1&pageSize=1&needsAttention=true',
        'page=1&pageSize=1&status=Requested',
        'page=1&pageSize=1&status=Approved',
      ]),
    );
  });

  testWidgets('a card opens the withdrawals list on its own filter', (
    tester,
  ) async {
    final api = _FakeAdminApi();
    final opened = await _pump(tester, api);

    for (final label in [
      'Needs attention',
      'Waiting for approval',
      'Approved, not yet paid',
    ]) {
      await tester.ensureVisible(_card(label));
      await tester.tap(_card(label));
      await tester.pump();
    }

    expect(opened, [
      WithdrawalsFilter.needsAttention,
      WithdrawalsFilter.requested,
      WithdrawalsFilter.approved,
    ]);
  });

  testWidgets('a failed withdrawals count shows the server message', (
    tester,
  ) async {
    final api = _FakeAdminApi(failWithdrawals: true);

    await _pump(tester, api);

    expect(find.text('Withdrawals are unavailable.'), findsOneWidget);
    expect(find.byType(AdminStatCard), findsNothing);
  });
}
