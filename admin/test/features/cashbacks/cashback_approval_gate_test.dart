import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';
import 'package:smartmoney_admin/features/cashbacks/cashback_approval_rules.dart';
import 'package:smartmoney_admin/features/cashbacks/screens/cashback_review_screen.dart';
import 'package:smartmoney_admin/features/cashbacks/services/admin_cashback_api_service.dart';

import '../../core/fakes.dart';

Map<String, dynamic> _row(
  String id, {
  required String networkStatus,
  String status = 'Pending',
  String? confirmedDate,
}) => {
  'id': id,
  'userId': 'u-$id',
  'userEmail': 'user-$id@example.com',
  'userFullName': 'User $id',
  'storeName': 'Myntra',
  'cashbackAmount': 600,
  'status': status,
  'networkStatus': networkStatus,
  'orderAmount': 12000,
  'commissionAmount': 1200,
  'currency': 'INR',
  'createdAt': '2026-10-12T10:00:00Z',
  'expectedConfirmationDate': '2026-11-11T10:00:00Z',
  'confirmedDate': confirmedDate,
};

/// A fake cashback API that records every request it receives.
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

  /// When set, approve answers with this instead of succeeding.
  http.Response? approveFailure;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> _handle(http.Request request) async {
    if (request.method == 'GET') {
      return _json({
        'items': rows,
        'totalCount': rows.length,
        'page': 1,
        'pageSize': 20,
      });
    }
    posts.add(request);
    if (approveFailure != null) return approveFailure!;
    return _json({
      'cashbackId': 'x',
      'status': 'Confirmed',
      'availableBalance': 600,
      'pendingBalance': 0,
    });
  }
}

Future<_Server> _pump(
  WidgetTester tester, {
  required bool superAdmin,
  List<Map<String, dynamic>>? rows,
}) async {
  tester.view.physicalSize = const Size(1800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server(
    rows ??
        [
          _row('pending', networkStatus: 'pending'),
          _row(
            'valid',
            networkStatus: 'validated',
            status: 'AwaitingAdminReview',
          ),
        ],
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CashbackReviewScreen(
          service: server.service,
          isSuperAdmin: superAdmin,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

/// Moves time on in steps. A row that is mid-action shows a spinner that never
/// stops animating, so pumpAndSettle would wait forever.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<ButtonStyleButton>(),
);

void main() {
  group('the rules', () {
    test('validated and paid are approvable, in any case', () {
      for (final s in ['validated', 'Validated', ' PAID ', 'paid']) {
        expect(cashbackApprovalRefusal(s), isNull, reason: s);
      }
    });

    test('everything else is refused with a plain reason', () {
      expect(cashbackApprovalRefusal('pending'), contains('still reports'));
      expect(cashbackApprovalRefusal('rejected'), contains('rejected'));
      expect(cashbackApprovalRefusal('cancelled'), contains('cancelled'));
      expect(cashbackApprovalRefusal('reversed'), contains('reversed'));
      expect(cashbackApprovalRefusal(''), contains('not known'));
      expect(cashbackApprovalRefusal('weird'), contains('"weird"'));
    });
  });

  group('a normal admin', () {
    testWidgets(
      'can approve a validated sale and cannot approve a pending one',
      (tester) async {
        await _pump(tester, superAdmin: false);

        final pendingApprove = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Approve').first,
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        final validApprove = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Approve').last,
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );

        // Rows are in server order: pending first, validated second.
        expect(pendingApprove.onPressed, isNull);
        expect(validApprove.onPressed, isNotNull);
        expect(find.text('Approve anyway…'), findsNothing);
      },
    );

    testWidgets('approving a validated sale sends no override', (tester) async {
      final server = await _pump(tester, superAdmin: false);

      await tester.tap(find.text('Approve').last);
      await _advance(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: _button('Approve'),
        ),
      );
      await _advance(tester);

      final request = server.posts.single;
      expect(request.url.path, '/api/admin/cashbacks/valid/approve');
      expect(request.body, isEmpty);
    });

    testWidgets('a refusal from the server is shown as it is', (tester) async {
      final server = await _pump(tester, superAdmin: false);
      server.approveFailure = http.Response(
        jsonEncode({'message': 'The affiliate network still reports pending.'}),
        409,
        headers: {'content-type': 'application/json'},
      );

      await tester.tap(find.text('Approve').last);
      await _advance(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: _button('Approve'),
        ),
      );
      await _advance(tester);

      expect(
        find.text('The affiliate network still reports pending.'),
        findsOneWidget,
      );
    });
  });

  group('a SuperAdmin', () {
    testWidgets(
      'sees Approve anyway on a pending sale and Approve on a valid one',
      (tester) async {
        await _pump(tester, superAdmin: true);

        expect(find.text('Approve anyway…'), findsOneWidget);
        expect(find.text('Approve'), findsOneWidget);
      },
    );

    testWidgets('must give a reason, which is sent with the override', (
      tester,
    ) async {
      final server = await _pump(tester, superAdmin: true);

      await tester.tap(find.text('Approve anyway…'));
      await _advance(tester);
      expect(find.text('Approve anyway'), findsWidgets);

      // An empty reason is refused and nothing is sent.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: _button('Approve anyway'),
        ),
      );
      await _advance(tester);
      expect(
        find.text('A reason is required to approve against the network.'),
        findsOneWidget,
      );
      expect(server.posts, isEmpty);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '  Merchant emailed the confirmation  ',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: _button('Approve anyway'),
        ),
      );
      await _advance(tester);

      final request = server.posts.single;
      expect(request.url.path, '/api/admin/cashbacks/pending/approve');
      expect(jsonDecode(request.body), {
        'reason': 'Merchant emailed the confirmation',
        'override': true,
      });
    });

    testWidgets('cancelling the reason dialog sends nothing', (tester) async {
      final server = await _pump(tester, superAdmin: true);

      await tester.tap(find.text('Approve anyway…'));
      await _advance(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: _button('Cancel'),
        ),
      );
      await _advance(tester);

      expect(server.posts, isEmpty);
    });
  });

  testWidgets('Reject is always offered, even while Approve is blocked', (
    tester,
  ) async {
    await _pump(tester, superAdmin: false);

    expect(find.text('Reject'), findsNWidgets(2));
  });
}
