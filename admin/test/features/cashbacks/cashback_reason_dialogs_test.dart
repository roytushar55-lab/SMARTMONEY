import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';
import 'package:smartmoney_admin/features/cashbacks/screens/cashback_review_screen.dart';
import 'package:smartmoney_admin/features/cashbacks/services/admin_cashback_api_service.dart';

import '../../core/fakes.dart';

Map<String, dynamic> _row(
  String id, {
  String networkStatus = 'pending',
  String status = 'Pending',
  String queue = 'WaitingOnNetwork',
  String? confirmedDate,
}) => {
  'id': id,
  'userId': 'u-$id',
  'userEmail': 'user-$id@example.com',
  'userFullName': 'User $id',
  'storeName': 'Myntra',
  'cashbackAmount': 600,
  'status': status,
  'queue': queue,
  'isOverdue': false,
  'networkStatus': networkStatus,
  'orderAmount': 12000,
  'commissionAmount': 1200,
  'currency': 'INR',
  'createdAt': '2026-10-12T10:00:00Z',
  'expectedConfirmationDate': '2026-11-11T10:00:00Z',
  'confirmedDate': confirmedDate,
};

class _Server {
  _Server(this.rows) {
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
    service = AdminCashbackApiService(
      client: AuthorizedApiClient(
        client: MockClient(_handle),
        tokenStorageService: storage,
        refresher: refresher,
        baseUrl: 'https://example.test',
        timeout: const Duration(seconds: 5),
      ),
    );
  }

  final List<Map<String, dynamic>> rows;
  late final AdminCashbackApiService service;
  final List<http.Request> posts = [];
  int lists = 0;
  http.Response? decisionFailure;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> _handle(http.Request request) async {
    if (request.method == 'GET') {
      if (request.url.path.endsWith('/summary')) return _json({});
      lists++;
      return _json({
        'items': rows,
        'totalCount': rows.length,
        'page': 1,
        'pageSize': 20,
      });
    }
    posts.add(request);
    if (decisionFailure != null) return decisionFailure!;
    return _json({
      'cashbackId': 'x',
      'status': 'Rejected',
      'availableBalance': 0,
      'pendingBalance': 0,
    });
  }
}

Future<_Server> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> rows,
) async {
  tester.view.physicalSize = const Size(1800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server(rows);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CashbackReviewScreen(
          service: server.service,
          isSuperAdmin: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Finder _button(String label) => _inDialog(
  find.ancestor(
    of: find.text(label),
    matching: find.bySubtype<ButtonStyleButton>(),
  ),
);

Future<void> _openDialog(WidgetTester tester, String action) async {
  await tester.tap(find.text(action));
  await _advance(tester);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_inDialog(find.byType(TextFormField)), text);
}

void main() {
  for (final c in [
    (
      action: 'Reject',
      title: 'Reject cashback',
      path: '/api/admin/cashbacks/pending/reject',
      error: 'A reason is required to reject a cashback.',
      rows: [_row('pending')],
    ),
    (
      action: 'Reverse',
      title: 'Reverse cashback',
      path: '/api/admin/cashbacks/rev/reverse',
      error: 'A reason is required to reverse a cashback.',
      rows: [
        _row(
          'rev',
          networkStatus: 'reversed',
          status: 'AwaitingAdminReview',
          queue: 'ReversalsToDecide',
          confirmedDate: '2026-10-01T00:00:00Z',
        ),
      ],
    ),
  ]) {
    group('${c.action} asks for a reason', () {
      testWidgets('the dialog explains and has a reason box', (tester) async {
        await _pump(tester, c.rows);
        await _openDialog(tester, c.action);

        expect(_inDialog(find.text(c.title)), findsOneWidget);
        expect(_inDialog(find.byType(TextFormField)), findsOneWidget);
        expect(_inDialog(find.textContaining('Say why')), findsOneWidget);
      });

      testWidgets('an empty or blank reason is refused and sends nothing', (
        tester,
      ) async {
        final server = await _pump(tester, c.rows);
        await _openDialog(tester, c.action);

        await tester.tap(_button(c.action));
        await _advance(tester);
        expect(find.text(c.error), findsOneWidget);

        await _type(tester, '    ');
        await tester.tap(_button(c.action));
        await _advance(tester);
        expect(find.text(c.error), findsOneWidget);
        expect(server.posts, isEmpty);
      });

      testWidgets('the trimmed reason is sent as the body', (tester) async {
        final server = await _pump(tester, c.rows);
        await _openDialog(tester, c.action);

        await _type(tester, '  Order was returned by the customer  ');
        await tester.tap(_button(c.action));
        await _advance(tester);

        final request = server.posts.single;
        expect(request.url.path, c.path);
        expect(jsonDecode(request.body), {
          'reason': 'Order was returned by the customer',
        });
      });

      testWidgets('cancelling sends nothing and keeps the row', (tester) async {
        final server = await _pump(tester, c.rows);
        await _openDialog(tester, c.action);

        await tester.tap(_button('Cancel'));
        await _advance(tester);

        expect(server.posts, isEmpty);
        expect(find.text(c.action), findsOneWidget);
      });

      testWidgets('success reloads the list', (tester) async {
        final server = await _pump(tester, c.rows);
        final before = server.lists;
        await _openDialog(tester, c.action);

        await _type(tester, 'a reason');
        await tester.tap(_button(c.action));
        await _advance(tester);

        expect(server.lists, before + 1);
      });

      testWidgets('a refusal from the server is shown as it is', (
        tester,
      ) async {
        final server = await _pump(tester, c.rows);
        server.decisionFailure = http.Response(
          jsonEncode({'message': 'The server said no.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
        await _openDialog(tester, c.action);

        await _type(tester, 'a reason');
        await tester.tap(_button(c.action));
        await _advance(tester);

        expect(find.text('The server said no.'), findsOneWidget);
      });
    });
  }

  testWidgets('the service sends a trimmed reason body for both', (
    tester,
  ) async {
    final server = _Server([]);
    await server.service.reject('a', '  one ');
    await server.service.reverse('b', ' two  ');

    expect(server.posts.map((r) => r.url.path), [
      '/api/admin/cashbacks/a/reject',
      '/api/admin/cashbacks/b/reverse',
    ]);
    expect(server.posts.map((r) => jsonDecode(r.body)), [
      {'reason': 'one'},
      {'reason': 'two'},
    ]);
  });
}
