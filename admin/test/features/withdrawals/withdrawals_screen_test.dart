import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartmoney_admin/features/withdrawals/screens/withdrawals_screen.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawal_queues.dart';

import 'withdrawal_test_support.dart';

const _summaryJson = {
  'toDecide': 3,
  'toDecideAmount': 1500.5,
  'toPay': 2,
  'toPayAmount': 988.2,
  'inProgress': 1,
  'history': 40,
  'needsAttention': 4,
  'paidLast30Days': 12,
  'paidLast30DaysAmount': 6000,
};

/// Answers the list with [list] and the summary with [summary] (or the
/// default numbers).
Future<http.Response> Function(http.Request) _router(
  Future<http.Response> Function(http.Request request) list, {
  Future<http.Response> Function(http.Request request)? summary,
}) {
  return (request) {
    if (request.url.path.endsWith('/summary')) {
      return summary != null
          ? summary(request)
          : Future.value(jsonResponse(_summaryJson));
    }
    return list(request);
  };
}

Future<http.Response> Function(http.Request) _listOf(
  List<Map<String, dynamic>> rows,
) => _router((_) async => jsonResponse(withdrawalPage(rows)));

List<http.Request> _lists(FakeWithdrawalServer server) =>
    server.seen.where((r) => r.url.path == '/api/admin/withdrawals').toList();

List<http.Request> _summaries(FakeWithdrawalServer server) =>
    server.seen.where((r) => r.url.path.endsWith('/summary')).toList();

Map<String, String> _lastList(FakeWithdrawalServer server) =>
    _lists(server).last.url.queryParameters;

Future<void> _pump(
  WidgetTester tester,
  FakeWithdrawalServer server, {
  Size size = const Size(1600, 1200),
  WithdrawalsScreen? screen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: screen ?? WithdrawalsScreen(service: server.service),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, WithdrawalQueue queue) async {
  // The test font is wide, so the tab row can scroll sideways.
  final tab = find.byKey(ValueKey('queue-tab-${queue.apiName}'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('withdrawal-search')), text);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Finder _inTile(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

void main() {
  group('opening the page', () {
    testWidgets('lists To decide first, asks for the numbers, shows the card', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));

      await _pump(tester, server);

      expect(_lastList(server), {
        'page': '1',
        'pageSize': '20',
        'queue': 'ToDecide',
      });
      expect(_summaries(server), hasLength(1));
      expect(find.text('Withdraw Test User'), findsOneWidget);
      expect(find.text('wd-user-1011@example.com'), findsOneWidget);
      expect(find.textContaining('To pay ₹494.10'), findsOneWidget);
      expect(find.textContaining('after ₹5.90 fee'), findsOneWidget);
      expect(find.textContaining('UPI'), findsWidgets);
      expect(find.textContaining('te****@okhdfc'), findsWidgets);
      expect(find.text('WD20261011K7QM2XA9PD'), findsOneWidget);
      expect(find.textContaining('Waiting for you'), findsOneWidget);
    });

    testWidgets('each tab shows its count', (tester) async {
      await _pump(tester, FakeWithdrawalServer(_listOf([withdrawalRow()])));

      expect(_textOf(tester, 'queue-count-ToDecide'), '3');
      expect(_textOf(tester, 'queue-count-ToPay'), '2');
      expect(_textOf(tester, 'queue-count-InProgress'), '1');
      expect(_textOf(tester, 'queue-count-History'), '40');
    });

    testWidgets('the strip shows counts, rupees and the paid total', (
      tester,
    ) async {
      await _pump(tester, FakeWithdrawalServer(_listOf([withdrawalRow()])));

      expect(_inTile('summary-to-decide', '3'), findsOneWidget);
      expect(
        _inTile('summary-to-decide', '₹1,500.50 requested'),
        findsOneWidget,
      );
      expect(_inTile('summary-to-pay', '2'), findsOneWidget);
      expect(_inTile('summary-to-pay', '₹988.20 owed now'), findsOneWidget);
      expect(_inTile('summary-attention', '4'), findsOneWidget);
      expect(_inTile('summary-paid', '₹6,000.00'), findsOneWidget);
      expect(_inTile('summary-paid', '12 withdrawals'), findsOneWidget);
    });

    testWidgets('if the summary fails the list still works, tiles read —', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(
        _router(
          (_) async => jsonResponse(withdrawalPage([withdrawalRow()])),
          summary: (_) async => jsonResponse({'message': 'no'}, 500),
        ),
      );

      await _pump(tester, server);

      expect(find.text('Withdraw Test User'), findsOneWidget);
      expect(_inTile('summary-to-decide', '—'), findsOneWidget);
      expect(find.byKey(const ValueKey('queue-count-ToDecide')), findsNothing);
    });

    testWidgets('shows a spinner with a message while loading', (tester) async {
      final gate = Completer<http.Response>();
      final server = FakeWithdrawalServer(_router((_) => gate.future));
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WithdrawalsScreen(service: server.service)),
        ),
      );
      await tester.pump();

      expect(find.text('Loading withdrawals...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      gate.complete(jsonResponse(withdrawalPage([withdrawalRow()])));
      await tester.pumpAndSettle();

      expect(find.text('Loading withdrawals...'), findsNothing);
    });
  });

  group('what a card says', () {
    testWidgets('hides the fee when the user pays none', (tester) async {
      await _pump(
        tester,
        FakeWithdrawalServer(
          _listOf([
            withdrawalRow({'userFee': 0, 'netAmount': 500}),
          ]),
        ),
      );

      expect(find.textContaining('fee'), findsNothing);
      expect(find.textContaining('To pay ₹500.00'), findsOneWidget);
    });

    testWidgets('labels a bank transfer', (tester) async {
      await _pump(
        tester,
        FakeWithdrawalServer(
          _listOf([
            withdrawalRow({
              'method': 'BankTransfer',
              'destinationMasked': 'HDFC0001234 ****6789',
            }),
          ]),
        ),
      );

      expect(find.textContaining('Bank transfer'), findsWidgets);
      expect(find.textContaining('HDFC0001234 ****6789'), findsWidgets);
    });

    testWidgets('an Approved one says what to pay where, then record it', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeWithdrawalServer(
          _listOf([
            withdrawalRow({
              'status': 'Approved',
              'queue': 'ToPay',
              'approvedAt': '2026-10-11T12:31:00Z',
            }),
          ]),
        ),
      );

      expect(
        find.textContaining('Pay ₹494.10 to te****@okhdfc by UPI'),
        findsOneWidget,
      );
      expect(find.textContaining('record the bank reference'), findsOneWidget);
    });

    testWidgets('a paid one shows the bank reference and no buttons', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeWithdrawalServer(
          _listOf([
            withdrawalRow({
              'status': 'Completed',
              'queue': 'History',
              'providerReference': 'UTR123456',
              'settledAt': '2026-10-11T13:00:00Z',
            }),
          ]),
        ),
      );

      expect(find.textContaining('Bank reference UTR123456'), findsOneWidget);
      expect(find.text('paid'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Decline'), findsNothing);
      expect(find.textContaining('Pay…'), findsNothing);
    });

    testWidgets('failed, declined and cancelled say why in words', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeWithdrawalServer(
          _listOf([
            withdrawalRow({
              'id': 'f',
              'status': 'Failed',
              'queue': 'History',
              'failureReason': 'The bank refused it.',
            }),
            withdrawalRow({
              'id': 'r',
              'status': 'Rejected',
              'queue': 'History',
              'failureReason': 'Account name does not match.',
            }),
            withdrawalRow({
              'id': 'c',
              'status': 'Cancelled',
              'queue': 'History',
            }),
          ]),
        ),
      );

      expect(find.text('Failed. The bank refused it.'), findsOneWidget);
      expect(
        find.text('Declined. Account name does not match.'),
        findsOneWidget,
      );
      expect(find.textContaining('Cancelled by the user'), findsOneWidget);
      expect(find.text('not paid'), findsNWidgets(3));
    });

    testWidgets('only flagged cards show the attention note, with the note', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeWithdrawalServer(
          _listOf([
            withdrawalRow({'id': 'plain'}),
            withdrawalRow({
              'id': 'flagged',
              'status': 'Processing',
              'queue': 'InProgress',
              'needsAttention': true,
              'reviewNote': 'Provider says paid after we failed it.',
              'lastError': 'ignored when there is a note',
            }),
          ]),
        ),
      );

      expect(
        find.byKey(const ValueKey('withdrawal-attention-note')),
        findsOneWidget,
      );
      expect(
        find.text('Provider says paid after we failed it.'),
        findsOneWidget,
      );
      expect(find.text('ignored when there is a note'), findsNothing);
      expect(find.text('Needs attention'), findsWidgets);
    });

    testWidgets(
      'the note falls back to the provider error, then a general line',
      (tester) async {
        await _pump(
          tester,
          FakeWithdrawalServer(
            _listOf([
              withdrawalRow({
                'id': 'a',
                'needsAttention': true,
                'lastError': 'Provider: temporary outage.',
              }),
              withdrawalRow({'id': 'b', 'needsAttention': true}),
            ]),
          ),
        );

        expect(find.text('Provider: temporary outage.'), findsOneWidget);
        expect(
          find.textContaining('does not match our records'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a request left over a day is marked, a fresh one is not', (
      tester,
    ) async {
      final long = DateTime.now().toUtc().subtract(const Duration(days: 3));
      final fresh = DateTime.now().toUtc().subtract(const Duration(hours: 2));

      await _pump(
        tester,
        FakeWithdrawalServer(
          _listOf([
            withdrawalRow({'id': 'old', 'requestedAt': long.toIso8601String()}),
            withdrawalRow({
              'id': 'new',
              'requestedAt': fresh.toIso8601String(),
            }),
          ]),
        ),
      );

      final ages = find
          .byKey(const ValueKey('withdrawal-age'))
          .evaluate()
          .map((e) => (e.widget as Text))
          .toList();
      expect(ages.map((t) => t.data), [
        'Requested 3 days ago',
        'Requested 2 h ago',
      ]);
      expect(ages[0].style!.fontWeight, FontWeight.w700);
      expect(ages[1].style!.fontWeight, isNot(FontWeight.w700));
    });
  });

  group('tabs', () {
    testWidgets('each tab asks for its own queue', (tester) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);

      await _tapTab(tester, WithdrawalQueue.toPay);
      expect(_lastList(server)['queue'], 'ToPay');

      await _tapTab(tester, WithdrawalQueue.inProgress);
      expect(_lastList(server)['queue'], 'InProgress');

      await _tapTab(tester, WithdrawalQueue.history);
      expect(_lastList(server)['queue'], 'History');
      expect(_lastList(server).containsKey('status'), isFalse);
    });

    testWidgets('History has a chip for every settled status', (tester) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);
      expect(find.byKey(const ValueKey('history-chip-All')), findsNothing);

      await _tapTab(tester, WithdrawalQueue.history);
      for (final status in ['Completed', 'Failed', 'Rejected', 'Cancelled']) {
        await tester.tap(find.byKey(ValueKey('history-chip-$status')));
        await tester.pumpAndSettle();
        expect(_lastList(server)['status'], status);
        expect(_lastList(server)['queue'], 'History');
      }

      await tester.tap(find.byKey(const ValueKey('history-chip-All')));
      await tester.pumpAndSettle();
      expect(_lastList(server).containsKey('status'), isFalse);
    });

    testWidgets('leaving History forgets the status chip', (tester) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);
      await _tapTab(tester, WithdrawalQueue.history);
      await tester.tap(find.byKey(const ValueKey('history-chip-Failed')));
      await tester.pumpAndSettle();

      await _tapTab(tester, WithdrawalQueue.toPay);
      expect(_lastList(server).containsKey('status'), isFalse);
      await _tapTab(tester, WithdrawalQueue.history);
      expect(_lastList(server).containsKey('status'), isFalse);
    });

    testWidgets('changing a tab goes back to page 1', (tester) async {
      final server = FakeWithdrawalServer(
        _router(
          (request) async => jsonResponse(
            withdrawalPage(
              [withdrawalRow()],
              totalCount: 100,
              page: int.parse(request.url.queryParameters['page']!),
            ),
          ),
        ),
      );
      await _pump(tester, server);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(_lastList(server)['page'], '2');

      await _tapTab(tester, WithdrawalQueue.toPay);

      expect(_lastList(server)['page'], '1');
    });
  });

  group('search, attention and dates', () {
    testWidgets('search waits for a pause, trims, and keeps the tab', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);
      await _tapTab(tester, WithdrawalQueue.toPay);
      final before = _lists(server).length;

      await tester.enterText(
        find.byKey(const ValueKey('withdrawal-search')),
        '  utr123 ',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_lists(server).length, before, reason: 'still typing');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_lists(server).length, before + 1);
      expect(_lastList(server)['search'], 'utr123');
      expect(_lastList(server)['queue'], 'ToPay');
    });

    testWidgets('Enter searches at once, the clear button undoes it', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);

      await tester.enterText(
        find.byKey(const ValueKey('withdrawal-search')),
        '494.10',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(_lastList(server)['search'], '494.10');

      await tester.tap(find.byKey(const ValueKey('clear-search')));
      await tester.pumpAndSettle();
      expect(_lastList(server).containsKey('search'), isFalse);
    });

    testWidgets('the attention chip filters, shows its count, toggles back', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);
      expect(find.text('Needs attention (4)'), findsOneWidget);
      expect(_lastList(server).containsKey('needsAttention'), isFalse);

      await tester.tap(find.byKey(const ValueKey('attention-chip')));
      await tester.pumpAndSettle();
      expect(_lastList(server)['needsAttention'], 'true');
      expect(_lastList(server)['queue'], 'ToDecide');

      await tester.tap(find.byKey(const ValueKey('attention-chip')));
      await tester.pumpAndSettle();
      expect(_lastList(server).containsKey('needsAttention'), isFalse);
    });

    testWidgets('Clear filters resets search and attention', (tester) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);
      expect(find.byKey(const ValueKey('clear-filters')), findsNothing);

      await _search(tester, 'asha');
      await tester.tap(find.byKey(const ValueKey('attention-chip')));
      await tester.pumpAndSettle();
      expect(_lastList(server)['search'], 'asha');
      expect(_lastList(server)['needsAttention'], 'true');

      await tester.tap(find.byKey(const ValueKey('clear-filters')));
      await tester.pumpAndSettle();

      expect(_lastList(server).containsKey('search'), isFalse);
      expect(_lastList(server).containsKey('needsAttention'), isFalse);
      expect(find.byKey(const ValueKey('clear-filters')), findsNothing);
    });

    test('the service sends every filter, the dates as UTC instants', () async {
      final server = FakeWithdrawalServer(_listOf([]));
      await server.service.list(
        queue: 'History',
        status: 'Completed',
        needsAttentionOnly: true,
        search: ' a&b ',
        from: DateTime.utc(2026, 10, 9, 18, 30),
        to: DateTime.utc(2026, 10, 10, 18, 30),
        page: 2,
        pageSize: 50,
      );

      expect(_lastList(server), {
        'page': '2',
        'pageSize': '50',
        'status': 'Completed',
        'queue': 'History',
        'needsAttention': 'true',
        'search': 'a&b',
        'from': '2026-10-09T18:30:00.000Z',
        'to': '2026-10-10T18:30:00.000Z',
      });
    });
  });

  group('empty, error and refresh', () {
    testWidgets('each tab says what empty means', (tester) async {
      final server = FakeWithdrawalServer(_listOf([]));
      await _pump(tester, server);
      expect(find.text(WithdrawalQueue.toDecide.emptyMessage), findsOneWidget);

      await _tapTab(tester, WithdrawalQueue.toPay);
      expect(find.text(WithdrawalQueue.toPay.emptyMessage), findsOneWidget);

      await _tapTab(tester, WithdrawalQueue.inProgress);
      expect(
        find.text(WithdrawalQueue.inProgress.emptyMessage),
        findsOneWidget,
      );

      await _tapTab(tester, WithdrawalQueue.history);
      expect(find.text(WithdrawalQueue.history.emptyMessage), findsOneWidget);
    });

    testWidgets('no match while filtering says so', (tester) async {
      final server = FakeWithdrawalServer(_listOf([]));
      await _pump(tester, server);

      await _search(tester, 'zzz');

      expect(find.text('No withdrawals match these filters.'), findsOneWidget);
    });

    testWidgets('only the attention filter on says nothing needs attention', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(_listOf([]));
      await _pump(tester, server);

      await tester.tap(find.byKey(const ValueKey('attention-chip')));
      await tester.pumpAndSettle();

      expect(find.text('Nothing needs attention here.'), findsOneWidget);
    });

    testWidgets('shows the server message on an error and can try again', (
      tester,
    ) async {
      var fail = true;
      final server = FakeWithdrawalServer(
        _router(
          (_) async => fail
              ? jsonResponse({
                  'message': 'The server is having a problem.',
                }, 500)
              : jsonResponse(withdrawalPage([withdrawalRow()])),
        ),
      );

      await _pump(tester, server);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('The server is having a problem.'), findsOneWidget);
      expect(find.text('Withdraw Test User'), findsNothing);

      fail = false;
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text('Withdraw Test User'), findsOneWidget);
    });

    testWidgets(
      'an unexpected response shape ends in an error, not a spinner',
      (tester) async {
        // A JSON list where an object is expected.
        final server = FakeWithdrawalServer(
          _router((_) async => jsonResponse([1, 2])),
        );

        await _pump(tester, server);

        expect(find.text('Loading withdrawals...'), findsNothing);
        expect(
          find.text('Could not load withdrawals. Please try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a 403 explains that the account is not allowed', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(
        _router((_) async => http.Response('', 403)),
      );

      await _pump(tester, server);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Loading withdrawals...'), findsNothing);
    });

    testWidgets('Refresh reloads the list and the numbers, same filters', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(_listOf([withdrawalRow()]));
      await _pump(tester, server);
      await _tapTab(tester, WithdrawalQueue.history);
      await tester.tap(find.byKey(const ValueKey('history-chip-Failed')));
      await tester.pumpAndSettle();
      final lists = _lists(server).length;
      final summaries = _summaries(server).length;

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(_lists(server).length, lists + 1);
      expect(_summaries(server).length, summaries + 1);
      expect(_lastList(server)['status'], 'Failed');
      expect(_lastList(server)['queue'], 'History');
    });

    testWidgets('Refresh is disabled while a load is in flight', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      final server = FakeWithdrawalServer(_router((_) => gate.future));
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WithdrawalsScreen(service: server.service)),
        ),
      );
      await tester.pump();

      final refresh = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Refresh'),
      );
      expect(refresh.onPressed, isNull);

      gate.complete(jsonResponse(withdrawalPage([withdrawalRow()])));
      await tester.pumpAndSettle();
    });
  });

  group('layout', () {
    testWidgets('fits a phone-width window with a flagged card and a pager', (
      tester,
    ) async {
      final server = FakeWithdrawalServer(
        _router(
          (_) async => jsonResponse(
            withdrawalPage(
              [
                withdrawalRow({
                  'needsAttention': true,
                  'status': 'Processing',
                  'queue': 'InProgress',
                  'userFullName': 'A Customer With A Very Long Name Indeed',
                  'userEmail': 'a.very.long.address.indeed@example-company.com',
                  'reviewNote': 'x' * 300,
                }),
              ],
              totalCount: 4567,
              page: 12,
            ),
          ),
        ),
      );

      await _pump(tester, server, size: const Size(380, 3000));

      expect(find.text('4567 total · page 12 of 229'), findsOneWidget);
      expect(find.byTooltip('Next page'), findsOneWidget);
      expect(tester.takeException(), isNull); // no RenderFlex overflow
    });
  });

  group('paging', () {
    http.Response pageOf(int page) => jsonResponse(
      withdrawalPage(
        [
          withdrawalRow({'id': 'page-$page', 'userFullName': 'Person $page'}),
        ],
        totalCount: 45,
        page: page,
      ),
    );

    testWidgets('shows the totals and walks forward and back', (tester) async {
      final server = FakeWithdrawalServer(
        _router(
          (request) async =>
              pageOf(int.parse(request.url.queryParameters['page']!)),
        ),
      );
      await _pump(tester, server);

      expect(find.text('45 total · page 1 of 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Person 2'), findsOneWidget);
      expect(find.text('45 total · page 2 of 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      expect(find.text('Person 1'), findsOneWidget);
    });
  });

  group('overlapping requests', () {
    testWidgets('a slow earlier response never overwrites a later one', (
      tester,
    ) async {
      final slowToDecide = Completer<http.Response>();
      final server = FakeWithdrawalServer(
        _router((request) {
          if (request.url.queryParameters['queue'] == 'ToDecide') {
            return slowToDecide.future;
          }
          return Future.value(
            jsonResponse(
              withdrawalPage([
                withdrawalRow({
                  'id': 'approved-one',
                  'status': 'Approved',
                  'queue': 'ToPay',
                  'userFullName': 'Approved Person',
                }),
              ]),
            ),
          );
        }),
      );

      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WithdrawalsScreen(service: server.service)),
        ),
      );
      await tester.pump(); // To decide is still loading

      await _tapTab(tester, WithdrawalQueue.toPay);
      expect(find.text('Approved Person'), findsOneWidget);

      // The slow To decide response finally arrives.
      slowToDecide.complete(
        jsonResponse(
          withdrawalPage([
            withdrawalRow({
              'id': 'requested-one',
              'userFullName': 'Stale Person',
            }),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approved Person'), findsOneWidget);
      expect(find.text('Stale Person'), findsNothing);
    });
  });

  testWidgets('leaving the page mid-load does not throw', (tester) async {
    final gate = Completer<http.Response>();
    final server = FakeWithdrawalServer(_router((_) => gate.future));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WithdrawalsScreen(service: server.service)),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    gate.complete(jsonResponse(withdrawalPage([withdrawalRow()])));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('the words', () {
    test('queue names map from raw statuses', () {
      expect(WithdrawalQueue.forStatus('Requested'), WithdrawalQueue.toDecide);
      expect(WithdrawalQueue.forStatus('Approved'), WithdrawalQueue.toPay);
      expect(
        WithdrawalQueue.forStatus('Processing'),
        WithdrawalQueue.inProgress,
      );
      for (final settled in ['Completed', 'Failed', 'Rejected', 'Cancelled']) {
        expect(WithdrawalQueue.forStatus(settled), WithdrawalQueue.history);
      }
      expect(WithdrawalQueue.fromApi('ToPay'), WithdrawalQueue.toPay);
      expect(WithdrawalQueue.fromApi('Nope'), isNull);
    });
  });
}
