import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmoney_admin/core/auth/refresh_token_response.dart';
import 'package:smartmoney_admin/core/auth/token_refresher.dart';
import 'package:smartmoney_admin/core/network/authorized_api_client.dart';
import 'package:smartmoney_admin/features/cashbacks/cashback_queues.dart';
import 'package:smartmoney_admin/features/cashbacks/models/admin_cashback.dart';
import 'package:smartmoney_admin/features/cashbacks/screens/cashback_review_screen.dart';
import 'package:smartmoney_admin/features/cashbacks/services/admin_cashback_api_service.dart';
import 'package:smartmoney_admin/features/cashbacks/widgets/cashback_card.dart';

import '../../core/fakes.dart';

Map<String, dynamic> _row(
  String id, {
  String queue = 'ReadyToApprove',
  String networkStatus = 'validated',
  String status = 'AwaitingAdminReview',
  String? confirmedDate,
  bool isOverdue = false,
  double cashback = 600,
  String name = 'Asha Rao',
  String expected = '2026-11-11T10:00:00Z',
}) => {
  'id': id,
  'userId': 'u-$id',
  'userEmail': '$id@example.com',
  'userFullName': name,
  'storeName': 'Myntra',
  'cashbackAmount': cashback,
  'status': status,
  'queue': queue,
  'isOverdue': isOverdue,
  'networkStatus': networkStatus,
  'orderAmount': 12000,
  'commissionAmount': 1200,
  'currency': 'INR',
  'createdAt': '2026-10-12T10:00:00Z',
  'expectedConfirmationDate': expected,
  'confirmedDate': confirmedDate,
};

const _summaryJson = {
  'readyToApprove': 3,
  'reversalsToDecide': 2,
  'networkRejected': 1,
  'waitingOnNetwork': 30,
  'history': 100,
  'needsDecision': 6,
  'overdue': 5,
  'exposureAmount': 5260.5,
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

  List<Map<String, dynamic>> rows;
  late final AdminCashbackApiService service;
  final List<Uri> lists = [];
  final List<Uri> summaries = [];
  final List<http.Request> posts = [];
  bool summaryFails = false;
  bool listFails = false;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> _handle(http.Request request) async {
    if (request.method == 'GET') {
      if (request.url.path.endsWith('/summary')) {
        summaries.add(request.url);
        return summaryFails
            ? _json({'message': 'summary broke'}, 500)
            : _json(_summaryJson);
      }
      lists.add(request.url);
      if (listFails) return _json({'message': 'list broke'}, 500);
      return _json({
        'items': rows,
        'totalCount': rows.length,
        'page': 1,
        'pageSize': 20,
      });
    }
    posts.add(request);
    return _json({
      'cashbackId': 'x',
      'status': 'Confirmed',
      'availableBalance': 600,
      'pendingBalance': 0,
    });
  }

  Map<String, String> get lastList => lists.last.queryParameters;
}

Future<_Server> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>>? rows,
  String? initialStatus,
  bool superAdmin = false,
  Size size = const Size(1800, 1200),
  bool summaryFails = false,
  bool listFails = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server(rows ?? [_row('valid')]);
  server.summaryFails = summaryFails;
  server.listFails = listFails;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CashbackReviewScreen(
          service: server.service,
          initialStatus: initialStatus,
          isSuperAdmin: superAdmin,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

Future<void> _tapTab(WidgetTester tester, CashbackQueue queue) async {
  // The test font is wide, so the tab row can scroll sideways.
  final tab = find.byKey(ValueKey('queue-tab-${queue.apiName}'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// Types into the search box and waits for the pause that sends it.
Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('cashback-search')), text);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) {
  final text = tester.widget<Text>(find.byKey(ValueKey(key)));
  return text.data!;
}

void main() {
  group('opening the page', () {
    testWidgets('lists Ready to approve first and asks for the numbers', (
      tester,
    ) async {
      final server = await _pump(tester);

      expect(server.lastList['queue'], 'ReadyToApprove');
      expect(server.lastList.containsKey('status'), isFalse);
      expect(server.summaries, hasLength(1));
      expect(find.text('Asha Rao'), findsOneWidget);
    });

    testWidgets('each tab shows its count', (tester) async {
      await _pump(tester);

      expect(_textOf(tester, 'queue-count-ReadyToApprove'), '3');
      expect(_textOf(tester, 'queue-count-ReversalsToDecide'), '2');
      expect(_textOf(tester, 'queue-count-NetworkRejected'), '1');
      expect(_textOf(tester, 'queue-count-WaitingOnNetwork'), '30');
      expect(_textOf(tester, 'queue-count-History'), '100');
    });

    testWidgets('the strip shows the four numbers', (tester) async {
      await _pump(tester);

      Finder inTile(String key, String text) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.text(text),
      );

      expect(inTile('summary-needs-decision', '6'), findsOneWidget);
      expect(inTile('summary-waiting', '30'), findsOneWidget);
      expect(inTile('summary-overdue', '5'), findsOneWidget);
      expect(inTile('summary-exposure', '₹5,260.50'), findsOneWidget);
    });

    testWidgets('if the summary fails the list still works and tiles read —', (
      tester,
    ) async {
      await _pump(tester, summaryFails: true);

      expect(find.text('Asha Rao'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('summary-needs-decision')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a list error shows the message and Try again works', (
      tester,
    ) async {
      final server = await _pump(tester, listFails: true);
      expect(find.text('list broke'), findsOneWidget);

      server.listFails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Asha Rao'), findsOneWidget);
    });
  });

  group('tabs', () {
    testWidgets('choosing a tab asks for that queue', (tester) async {
      final server = await _pump(tester);

      await _tapTab(tester, CashbackQueue.networkRejected);
      expect(server.lastList['queue'], 'NetworkRejected');

      await _tapTab(tester, CashbackQueue.waitingOnNetwork);
      expect(server.lastList['queue'], 'WaitingOnNetwork');
    });

    testWidgets('History shows status chips and they filter', (tester) async {
      final server = await _pump(tester);
      expect(find.byKey(const ValueKey('history-chip-All')), findsNothing);

      await _tapTab(tester, CashbackQueue.history);
      expect(find.byKey(const ValueKey('history-chip-All')), findsOneWidget);
      expect(server.lastList.containsKey('status'), isFalse);

      await tester.tap(find.byKey(const ValueKey('history-chip-Reversed')));
      await tester.pumpAndSettle();
      expect(server.lastList['queue'], 'History');
      expect(server.lastList['status'], 'Reversed');

      await tester.tap(find.byKey(const ValueKey('history-chip-All')));
      await tester.pumpAndSettle();
      expect(server.lastList.containsKey('status'), isFalse);
    });

    testWidgets('leaving History forgets the status chip', (tester) async {
      final server = await _pump(tester);
      await _tapTab(tester, CashbackQueue.history);
      await tester.tap(find.byKey(const ValueKey('history-chip-Confirmed')));
      await tester.pumpAndSettle();

      await _tapTab(tester, CashbackQueue.readyToApprove);
      expect(server.lastList.containsKey('status'), isFalse);
      await _tapTab(tester, CashbackQueue.history);
      expect(server.lastList.containsKey('status'), isFalse);
    });

    testWidgets('each queue says what an empty list means', (tester) async {
      final server = await _pump(tester, rows: []);
      expect(
        find.text(CashbackQueue.readyToApprove.emptyMessage),
        findsOneWidget,
      );

      server.rows = [];
      await _tapTab(tester, CashbackQueue.waitingOnNetwork);
      expect(
        find.text(CashbackQueue.waitingOnNetwork.emptyMessage),
        findsOneWidget,
      );
    });
  });

  group('search, overdue and filters', () {
    testWidgets('search waits for a pause, trims, and is sent', (tester) async {
      final server = await _pump(tester);
      final before = server.lists.length;

      await tester.enterText(
        find.byKey(const ValueKey('cashback-search')),
        '  asha ',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(server.lists.length, before, reason: 'still typing');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(server.lists.length, before + 1);
      expect(server.lastList['search'], 'asha');
      expect(server.lastList['queue'], 'ReadyToApprove');
    });

    testWidgets('Enter searches at once', (tester) async {
      final server = await _pump(tester);

      await tester.enterText(
        find.byKey(const ValueKey('cashback-search')),
        '600',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(server.lastList['search'], '600');
    });

    testWidgets('the clear button empties the search and lists again', (
      tester,
    ) async {
      final server = await _pump(tester);
      await _search(tester, 'asha');
      expect(server.lastList['search'], 'asha');

      await tester.tap(find.byKey(const ValueKey('clear-search')));
      await tester.pumpAndSettle();

      expect(server.lastList.containsKey('search'), isFalse);
    });

    testWidgets('the Overdue chip filters, shows its count, and toggles back', (
      tester,
    ) async {
      final server = await _pump(tester);
      expect(find.text('Overdue (5)'), findsOneWidget);
      expect(server.lastList.containsKey('overdue'), isFalse);

      await tester.tap(find.byKey(const ValueKey('overdue-chip')));
      await tester.pumpAndSettle();
      expect(server.lastList['overdue'], 'true');
      expect(server.lastList['queue'], 'ReadyToApprove');

      await tester.tap(find.byKey(const ValueKey('overdue-chip')));
      await tester.pumpAndSettle();
      expect(server.lastList.containsKey('overdue'), isFalse);
    });

    testWidgets('Clear filters resets search and overdue', (tester) async {
      final server = await _pump(tester);
      expect(find.byKey(const ValueKey('clear-filters')), findsNothing);

      await _search(tester, 'asha');
      await tester.tap(find.byKey(const ValueKey('overdue-chip')));
      await tester.pumpAndSettle();
      expect(server.lastList['search'], 'asha');
      expect(server.lastList['overdue'], 'true');

      await tester.tap(find.byKey(const ValueKey('clear-filters')));
      await tester.pumpAndSettle();

      expect(server.lastList.containsKey('search'), isFalse);
      expect(server.lastList.containsKey('overdue'), isFalse);
      expect(find.byKey(const ValueKey('clear-filters')), findsNothing);
    });

    testWidgets('no match while filtering says so', (tester) async {
      final server = await _pump(tester);
      server.rows = [];
      await _search(tester, 'zzz');

      expect(find.text('No cashbacks match these filters.'), findsOneWidget);
    });

    testWidgets('a changed filter goes back to page 1', (tester) async {
      final server = await _pump(tester);
      server.rows = List.generate(20, (i) => _row('r$i'));
      await _tapTab(tester, CashbackQueue.waitingOnNetwork);
      expect(server.lastList['page'], '1');
    });

    test('the service sends the date range as UTC instants', () async {
      final server = _Server([]);
      await server.service.list(
        from: DateTime.utc(2026, 10, 9, 18, 30),
        to: DateTime.utc(2026, 10, 10, 18, 30),
        search: ' a&b ',
        queue: 'History',
        status: 'Confirmed',
        overdue: true,
        page: 2,
        pageSize: 50,
      );

      expect(server.lastList, {
        'page': '2',
        'pageSize': '50',
        'status': 'Confirmed',
        'queue': 'History',
        'overdue': 'true',
        'search': 'a&b',
        'from': '2026-10-09T18:30:00.000Z',
        'to': '2026-10-10T18:30:00.000Z',
      });
    });
  });

  group('arriving from a dashboard card', () {
    testWidgets('Awaiting review lists that raw status across the queues', (
      tester,
    ) async {
      final server = await _pump(tester, initialStatus: 'AwaitingAdminReview');

      expect(server.lastList['status'], 'AwaitingAdminReview');
      expect(server.lastList.containsKey('queue'), isFalse);
      expect(find.byKey(const ValueKey('raw-status-chip')), findsOneWidget);
      // Cards say which queue they are in, since the tab no longer does.
      expect(find.text('Ready to approve'), findsWidgets);
    });

    testWidgets('closing that chip goes back to Ready to approve', (
      tester,
    ) async {
      final server = await _pump(tester, initialStatus: 'Pending');

      await tester.tap(find.byKey(const ValueKey('raw-status-chip')));
      await tester.pumpAndSettle();

      expect(server.lastList['queue'], 'ReadyToApprove');
      expect(server.lastList.containsKey('status'), isFalse);
      expect(find.byKey(const ValueKey('raw-status-chip')), findsNothing);
    });

    testWidgets('a decided status opens History on that status', (
      tester,
    ) async {
      final server = await _pump(tester, initialStatus: 'Rejected');

      expect(server.lastList['queue'], 'History');
      expect(server.lastList['status'], 'Rejected');
    });

    testWidgets('Paid out from the dashboard still gets a chip', (
      tester,
    ) async {
      final server = await _pump(tester, initialStatus: 'PaidOut');

      expect(server.lastList['status'], 'PaidOut');
      expect(
        find.byKey(const ValueKey('history-chip-PaidOut')),
        findsOneWidget,
      );
    });
  });

  group('the cards', () {
    testWidgets('say why in words and show the numbers', (tester) async {
      await _pump(tester);

      expect(
        find.text('Network says validated. Safe to approve.'),
        findsOneWidget,
      );
      expect(find.text('₹600.00'), findsOneWidget);
      expect(find.textContaining('Order ₹12000.00'), findsOneWidget);
      expect(find.textContaining('Commission ₹1200.00'), findsOneWidget);
      expect(find.text('Network: validated'), findsOneWidget);
    });

    testWidgets('an overdue one is flagged with how late', (tester) async {
      await _pump(
        tester,
        rows: [
          _row(
            'late',
            queue: 'WaitingOnNetwork',
            networkStatus: 'pending',
            status: 'Pending',
            isOverdue: true,
            expected: '2020-01-01T00:00:00Z',
          ),
        ],
      );

      expect(find.text('Overdue'), findsWidgets);
      expect(find.textContaining('Overdue by'), findsOneWidget);
    });

    testWidgets('on a wide screen the buttons sit at the right edge', (
      tester,
    ) async {
      await _pump(tester, size: const Size(1800, 1200));

      final card = tester.getRect(find.byType(CashbackCard));
      final approve = tester.getRect(find.text('Approve'));
      final name = tester.getRect(find.text('Asha Rao'));

      expect(approve.right, greaterThan(card.right - 60));
      expect(approve.left, greaterThan(name.right));
      expect(approve.center.dy, closeTo(card.center.dy, 40));
    });

    testWidgets('on a phone width nothing overflows and Approve works', (
      tester,
    ) async {
      final server = await _pump(
        tester,
        size: const Size(400, 2400),
        rows: [
          _row('valid'),
          _row(
            'rev',
            queue: 'ReversalsToDecide',
            networkStatus: 'reversed',
            confirmedDate: '2026-10-01T00:00:00Z',
            name: 'A Very Long Customer Name That Keeps Going And Going',
          ),
        ],
        superAdmin: true,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Approve anyway…'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Approve'),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(
        server.posts.single.url.path,
        '/api/admin/cashbacks/valid/approve',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a previously confirmed one offers Reverse, not Reject', (
      tester,
    ) async {
      await _pump(
        tester,
        rows: [
          _row(
            'rev',
            queue: 'ReversalsToDecide',
            networkStatus: 'reversed',
            confirmedDate: '2026-10-01T00:00:00Z',
          ),
        ],
      );

      expect(find.text('Reverse'), findsOneWidget);
      expect(find.text('Reject'), findsNothing);
      expect(
        find.textContaining('Reverse it to take the money back'),
        findsOneWidget,
      );
    });

    testWidgets('decided cashback has no buttons', (tester) async {
      await _pump(
        tester,
        rows: [
          _row(
            'done',
            queue: 'History',
            status: 'Confirmed',
            networkStatus: 'paid',
          ),
        ],
      );

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Reverse'), findsNothing);
      expect(find.text('Confirmed'), findsOneWidget);
    });

    testWidgets('deciding reloads both the list and the numbers', (
      tester,
    ) async {
      final server = await _pump(tester);
      final lists = server.lists.length;
      final summaries = server.summaries.length;

      await tester.tap(find.text('Approve'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Approve'),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(server.posts, hasLength(1));
      expect(server.lists.length, lists + 1);
      expect(server.summaries.length, summaries + 1);
    });
  });

  group('the words', () {
    AdminCashback make({
      String status = 'AwaitingAdminReview',
      String queue = '',
      String network = 'pending',
      DateTime? expected,
      bool overdue = false,
    }) => AdminCashback(
      id: 'x',
      userId: 'u',
      userEmail: 'a@b.c',
      userFullName: 'A',
      storeName: null,
      cashbackAmount: 100,
      status: status,
      networkStatus: network,
      orderAmount: null,
      commissionAmount: null,
      currency: null,
      createdAt: DateTime.utc(2026, 10, 1),
      expectedConfirmationDate: expected ?? DateTime.utc(2026, 11, 1),
      confirmedDate: null,
      queue: queue,
      isOverdue: overdue,
    );

    test('every queue has a reason, and decided ones say what happened', () {
      for (final queue in CashbackQueue.values) {
        expect(
          cashbackReason(make(queue: queue.apiName, network: 'validated')),
          isNotEmpty,
          reason: queue.apiName,
        );
      }
      expect(cashbackReason(make(status: 'Rejected')), contains('Rejected'));
      expect(cashbackReason(make(status: 'Reversed')), contains('taken back'));
      expect(
        cashbackReason(make(status: 'Confirmed')),
        contains('available balance'),
      );
      expect(
        cashbackReason(make(queue: 'WaitingOnNetwork', network: 'pending')),
        contains('still reports this as pending'),
      );
      expect(
        cashbackReason(make(queue: 'NetworkRejected', network: 'cancelled')),
        contains('cancelled'),
      );
    });

    test('due text counts days, in the right direction', () {
      final now = DateTime.utc(2026, 10, 12, 15);
      String? due(DateTime expected, {bool overdue = false}) =>
          cashbackDueText(make(expected: expected, overdue: overdue), now);

      expect(due(DateTime.utc(2026, 10, 12, 1)), 'Due today');
      expect(due(DateTime.utc(2026, 10, 13)), 'Due in 1 day');
      expect(due(DateTime.utc(2026, 10, 24)), 'Due in 12 days');
      expect(due(DateTime.utc(2026, 10, 11)), 'Overdue by 1 day');
      expect(due(DateTime.utc(2026, 10, 9)), 'Overdue by 3 days');
      expect(
        due(DateTime.utc(2026, 10, 12, 20), overdue: true),
        'Overdue by 1 day',
        reason: 'the server says overdue, so never "due"',
      );
      expect(
        cashbackDueText(make(status: 'Confirmed'), now),
        isNull,
        reason: 'decided cashback has no due date',
      );
    });

    test('network colours: good green, pending blue, bad red, rest grey', () {
      expect(networkStatusColor('Validated'), networkStatusColor('paid'));
      expect(networkStatusColor('rejected'), networkStatusColor('reversed'));
      expect(networkStatusColor('pending'), isNot(networkStatusColor('paid')));
      expect(networkStatusColor('???'), isNot(networkStatusColor('pending')));
    });
  });
}
