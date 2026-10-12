import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';
import 'package:smartmoney_admin/features/cashbacks/cashback_event_copy.dart';
import 'package:smartmoney_admin/features/cashbacks/models/admin_cashback.dart';
import 'package:smartmoney_admin/features/cashbacks/screens/cashback_detail_dialog.dart';
import 'package:smartmoney_admin/features/cashbacks/screens/cashback_review_screen.dart';
import 'package:smartmoney_admin/features/cashbacks/services/admin_cashback_api_service.dart';

import '../../core/fakes.dart';

Map<String, dynamic> _row(
  String id, {
  String networkStatus = 'validated',
  String status = 'AwaitingAdminReview',
  String queue = 'ReadyToApprove',
  String? confirmedDate,
  bool isOverdue = false,
  String expected = '2026-11-11T10:00:00Z',
}) => {
  'id': id,
  'userId': 'u-$id',
  'userEmail': '$id@example.com',
  'userFullName': 'Asha Rao',
  'storeName': 'Myntra',
  'cashbackAmount': 300,
  'status': status,
  'queue': queue,
  'isOverdue': isOverdue,
  'networkStatus': networkStatus,
  'orderAmount': 6000,
  'commissionAmount': 600,
  'currency': 'INR',
  'createdAt': '2026-10-12T10:00:00Z',
  'expectedConfirmationDate': expected,
  'confirmedDate': confirmedDate,
};

Map<String, dynamic> _event(
  String type, {
  String? name,
  String? email,
  String? from,
  String to = 'Pending',
  String? network,
  String? reason,
  String at = '2026-10-12T10:00:00Z',
}) => {
  'id': 'e-$type-$at',
  'type': type,
  'actorUserId': name == null && email == null ? null : 'a1',
  'actorName': name,
  'actorEmail': email,
  'fromStatus': from,
  'toStatus': to,
  'amount': 300,
  'networkStatus': network,
  'reason': reason,
  'createdAt': at,
};

class _Server {
  _Server({this.events = const [], this.rows = const []}) {
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

  List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> rows;
  late final AdminCashbackApiService service;
  final List<Uri> eventRequests = [];
  final List<http.Request> posts = [];
  bool eventsFail = false;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> _handle(http.Request request) async {
    if (request.method != 'GET') {
      posts.add(request);
      return _json({
        'cashbackId': 'x',
        'status': 'Confirmed',
        'availableBalance': 0,
        'pendingBalance': 0,
      });
    }
    if (request.url.path.endsWith('/events')) {
      eventRequests.add(request.url);
      return eventsFail
          ? _json({'message': 'trail broke'}, 500)
          : _json(events);
    }
    if (request.url.path.endsWith('/summary')) return _json({});
    return _json({
      'items': rows,
      'totalCount': rows.length,
      'page': 1,
      'pageSize': 20,
    });
  }
}

AdminCashback _cashback(Map<String, dynamic> json) =>
    AdminCashback.fromJson(json);

Future<void> _openDialog(
  WidgetTester tester,
  _Server server,
  Map<String, dynamic> row, {
  Size size = const Size(1200, 1400),
  DateTime? now,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCashbackDetailDialog(
              context,
              cashback: _cashback(row),
              service: server.service,
              now: now ?? DateTime.utc(2026, 10, 12, 12),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('the summary', () {
    testWidgets(
      'shows at once, from the list row, and loads the trail for it',
      (tester) async {
        final server = _Server(events: [_event('Created', network: 'pending')]);
        await _openDialog(tester, server, _row('abc'));

        expect(
          server.eventRequests.single.path,
          '/api/admin/cashbacks/abc/events',
        );
        expect(find.text('Asha Rao'), findsOneWidget);
        expect(find.text('abc@example.com'), findsOneWidget);
        expect(find.text('Myntra'), findsOneWidget);
        expect(find.text('₹6000.00'), findsOneWidget);
        expect(find.text('₹600.00'), findsOneWidget);
        expect(find.text('₹300.00'), findsWidgets);
        expect(
          find.text('Network says validated. Safe to approve.'),
          findsOneWidget,
        );
        expect(find.text('Due in 30 days'), findsOneWidget);
      },
    );

    testWidgets('a confirmed date is shown only when there is one', (
      tester,
    ) async {
      final server = _Server();
      await _openDialog(tester, server, _row('abc'));
      expect(find.text('Confirmed'), findsNothing);

      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    });

    testWidgets('a confirmed one shows when', (tester) async {
      final server = _Server();
      await _openDialog(
        tester,
        server,
        _row(
          'abc',
          status: 'Confirmed',
          queue: 'History',
          confirmedDate: '2026-10-13T08:00:00Z',
        ),
      );

      expect(find.text('Confirmed'), findsWidgets);
      expect(find.textContaining('2026-10-13'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-approval-note')), findsNothing);
      expect(find.text('Due in 30 days'), findsNothing);
    });

    testWidgets(
      'a sale the network has not validated says what approving needs',
      (tester) async {
        final server = _Server();
        await _openDialog(
          tester,
          server,
          _row(
            'abc',
            networkStatus: 'pending',
            queue: 'WaitingOnNetwork',
            status: 'Pending',
          ),
        );

        final note = tester.widget<Text>(
          find.byKey(const ValueKey('detail-approval-note')),
        );
        expect(note.data, contains('still reports this sale as pending'));
      },
    );

    testWidgets('a validated one has no approving note', (tester) async {
      await _openDialog(tester, _Server(), _row('abc'));

      expect(find.byKey(const ValueKey('detail-approval-note')), findsNothing);
    });

    testWidgets('an overdue one says how late', (tester) async {
      await _openDialog(
        tester,
        _Server(),
        _row('abc', isOverdue: true, expected: '2026-10-09T00:00:00Z'),
      );

      expect(find.text('Overdue by 3 days'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });
  });

  group('the history', () {
    testWidgets('lists every event in order with who, what changed and why', (
      tester,
    ) async {
      final server = _Server(
        events: [
          _event(
            'Created',
            to: 'Pending',
            network: 'pending',
            at: '2026-10-12T10:00:00Z',
          ),
          _event(
            'NetworkStatusChanged',
            from: 'Pending',
            to: 'Pending',
            network: 'validated',
            at: '2026-10-12T11:00:00Z',
          ),
          _event(
            'FlaggedForReview',
            from: 'Pending',
            to: 'AwaitingAdminReview',
            network: 'validated',
            at: '2026-10-12T11:00:01Z',
          ),
          _event(
            'Approved',
            name: 'Asha Admin',
            email: 'asha@example.com',
            from: 'AwaitingAdminReview',
            to: 'Confirmed',
            network: 'validated',
            reason: 'Merchant emailed to confirm',
            at: '2026-10-12T12:00:00Z',
          ),
        ],
      );
      await _openDialog(
        tester,
        server,
        _row('abc', status: 'Confirmed', queue: 'History'),
      );

      expect(find.text('Created from the network report'), findsOneWidget);
      expect(find.text('Network changed its status'), findsOneWidget);
      expect(find.text('Sent for review'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('by the network'), findsNWidgets(3));
      expect(find.text('by Asha Admin (asha@example.com)'), findsOneWidget);
      expect(
        find.textContaining('Awaiting review to Confirmed'),
        findsOneWidget,
      );
      expect(find.textContaining('Network said validated'), findsWidgets);
      expect(find.text('“Merchant emailed to confirm”'), findsOneWidget);

      // Oldest first.
      final created = tester
          .getTopLeft(find.text('Created from the network report'))
          .dy;
      final approved = tester.getTopLeft(find.text('Approved')).dy;
      expect(created, lessThan(approved));
    });

    testWidgets('an override reads differently from a normal approval', (
      tester,
    ) async {
      final server = _Server(
        events: [
          _event(
            'ApprovedByOverride',
            name: 'Root Admin',
            from: 'Pending',
            to: 'Confirmed',
            network: 'pending',
            reason: 'Paid out of band',
          ),
        ],
      );
      await _openDialog(
        tester,
        server,
        _row('abc', status: 'Confirmed', queue: 'History'),
      );

      expect(find.text('Approved anyway (override)'), findsOneWidget);
      expect(find.text('by Root Admin'), findsOneWidget);
      expect(find.textContaining('Network said pending'), findsOneWidget);
    });

    testWidgets('a rejection and a reversal show their reasons', (
      tester,
    ) async {
      final server = _Server(
        events: [
          _event(
            'Rejected',
            email: 'a@x.co',
            from: 'Pending',
            to: 'Rejected',
            reason: 'Order was returned',
          ),
          _event(
            'Reversed',
            name: 'B',
            from: 'AwaitingAdminReview',
            to: 'Reversed',
            reason: 'Network clawed it back',
            at: '2026-10-13T10:00:00Z',
          ),
        ],
      );
      await _openDialog(
        tester,
        server,
        _row('abc', status: 'Reversed', queue: 'History'),
      );

      expect(find.text('by a@x.co'), findsOneWidget);
      expect(find.text('“Order was returned”'), findsOneWidget);
      expect(find.text('“Network clawed it back”'), findsOneWidget);
    });

    testWidgets('an event type we do not know is still shown', (tester) async {
      final server = _Server(events: [_event('SomethingNew')]);
      await _openDialog(tester, server, _row('abc'));

      expect(find.text('SomethingNew'), findsOneWidget);
    });

    testWidgets('no recorded history says so', (tester) async {
      await _openDialog(tester, _Server(events: []), _row('abc'));

      expect(find.byKey(const ValueKey('detail-no-history')), findsOneWidget);
    });

    testWidgets('a failed load shows the message, and Try again works', (
      tester,
    ) async {
      final server = _Server(events: [_event('Created')])..eventsFail = true;
      await _openDialog(tester, server, _row('abc'));

      expect(find.text('trail broke'), findsOneWidget);
      // The summary is still there.
      expect(find.text('Asha Rao'), findsOneWidget);

      server.eventsFail = false;
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Created from the network report'), findsOneWidget);
      expect(server.eventRequests, hasLength(2));
    });

    testWidgets('fits a phone width without overflow, with long text', (
      tester,
    ) async {
      final server = _Server(
        events: [
          _event(
            'Rejected',
            name: 'An Admin With A Very Long Name Indeed',
            email: 'an.admin.with.a.very.long.address@example-company.com',
            from: 'AwaitingAdminReview',
            to: 'Rejected',
            network: 'rejected',
            reason: 'x' * 400,
          ),
        ],
      );
      await _openDialog(
        tester,
        server,
        _row('abc', status: 'Rejected', queue: 'History'),
        size: const Size(380, 900),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Close closes it', (tester) async {
      await _openDialog(tester, _Server(), _row('abc'));

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(CashbackDetailDialog), findsNothing);
    });
  });

  group('from the list', () {
    Future<_Server> pumpList(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final server = _Server(
        rows: [_row('valid')],
        events: [_event('Created')],
      );
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

    testWidgets('tapping a card opens its history', (tester) async {
      final server = await pumpList(tester);
      expect(find.byKey(const ValueKey('card-details-hint')), findsOneWidget);

      await tester.tap(find.text('Asha Rao'));
      await tester.pumpAndSettle();

      expect(find.byType(CashbackDetailDialog), findsOneWidget);
      expect(
        server.eventRequests.single.path,
        '/api/admin/cashbacks/valid/events',
      );
      expect(find.text('Created from the network report'), findsOneWidget);
    });

    testWidgets('tapping a button decides, it does not open the card', (
      tester,
    ) async {
      final server = await pumpList(tester);

      await tester.tap(find.text('Reject'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CashbackDetailDialog), findsNothing);
      expect(server.eventRequests, isEmpty);
      expect(find.text('Reject cashback'), findsOneWidget);
    });
  });

  group('the words', () {
    AdminCashbackEvent event({
      String? name,
      String? email,
      String? from,
      String to = 'Pending',
    }) => AdminCashbackEvent.fromJson(
      _event('Approved', name: name, email: email, from: from, to: to),
    );

    test('who did it', () {
      expect(cashbackEventActor(event()), 'by the network');
      expect(cashbackEventActor(event(name: 'A')), 'by A');
      expect(cashbackEventActor(event(email: 'a@b.c')), 'by a@b.c');
      expect(
        cashbackEventActor(event(name: 'A', email: 'a@b.c')),
        'by A (a@b.c)',
      );
      expect(
        cashbackEventActor(event(name: '  ', email: ' ')),
        'by the network',
      );
    });

    test('the status change is shown only when it moved', () {
      expect(cashbackEventStatusChange(event()), isNull);
      expect(
        cashbackEventStatusChange(event(from: 'Pending', to: 'Pending')),
        isNull,
      );
      expect(
        cashbackEventStatusChange(
          event(from: 'Pending', to: 'AwaitingAdminReview'),
        ),
        'Pending to Awaiting review',
      );
    });

    test('every event type has its own words', () {
      const types = [
        'Created',
        'NetworkStatusChanged',
        'FlaggedForReview',
        'Approved',
        'ApprovedByOverride',
        'Rejected',
        'Reversed',
      ];
      final labels = types
          .map((t) => CashbackEventCopy.forType(t).label)
          .toSet();
      expect(labels, hasLength(types.length));
      expect(CashbackEventCopy.forType('').label, 'Unknown event');
    });

    test('blank text fields from the server read as missing', () {
      final e = AdminCashbackEvent.fromJson({
        'id': 'x',
        'type': 'Approved',
        'actorName': '  ',
        'reason': '',
        'networkStatus': ' ',
        'toStatus': 'Confirmed',
        'amount': 1,
        'createdAt': '2026-10-12T10:00:00Z',
      });
      expect(e.byAdmin, isFalse);
      expect(e.reason, isNull);
      expect(e.networkStatus, isNull);
    });
  });
}
