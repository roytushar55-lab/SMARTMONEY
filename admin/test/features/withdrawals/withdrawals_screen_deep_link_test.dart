import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmoney_admin/features/withdrawals/screens/withdrawal_detail_dialog.dart';
import 'package:smartmoney_admin/features/withdrawals/screens/withdrawals_screen.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawals_filter.dart';

import 'fake_withdrawal_backend.dart';
import 'withdrawal_test_support.dart';

Finder _buttonLabelled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<ButtonStyleButton>(),
);

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Future<void> _pump(
  WidgetTester tester,
  WithdrawalsScreen screen, {
  Size size = const Size(1600, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
  await tester.pumpAndSettle();
}

/// Moves time on in steps. A card that is mid-action shows a spinner that
/// never stops animating, so pumpAndSettle would wait forever.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Map<String, String> _lastList(FakeWithdrawalBackend backend) => backend
    .server
    .seen
    .lastWhere((r) => r.url.path == '/api/admin/withdrawals')
    .url
    .queryParameters;

FakeWithdrawalBackend _backend([List<Map<String, dynamic>>? rows]) =>
    FakeWithdrawalBackend(
      rows ??
          [
            withdrawalRow({'destination': upiDestination}),
          ],
    );

void main() {
  group('opening on a given filter', () {
    testWidgets('needs attention: every flagged one across the tabs', (
      tester,
    ) async {
      final backend = _backend([
        withdrawalRow({
          'status': 'Processing',
          'needsAttention': true,
          'queue': 'InProgress',
        }),
      ]);

      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: WithdrawalsFilter.needsAttention,
        ),
      );

      expect(_lastList(backend), {
        'page': '1',
        'pageSize': '20',
        'needsAttention': 'true',
      });
      expect(find.text('Withdraw Test User'), findsOneWidget);
      // No tab says which queue it is, so the card does.
      expect(find.text('In progress'), findsWidgets);
      expect(
        find.text('Needs attention (1)'),
        findsOneWidget,
        reason: 'the chip is on',
      );
    });

    testWidgets('turning that chip off goes back to To decide', (tester) async {
      final backend = _backend();

      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: WithdrawalsFilter.needsAttention,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('attention-chip')));
      await tester.pumpAndSettle();

      expect(_lastList(backend)['queue'], 'ToDecide');
      expect(_lastList(backend).containsKey('needsAttention'), isFalse);
    });

    testWidgets('approved: the To pay tab', (tester) async {
      final backend = _backend();

      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: WithdrawalsFilter.approved,
        ),
      );

      expect(_lastList(backend), {
        'page': '1',
        'pageSize': '20',
        'queue': 'ToPay',
      });
      expect(find.text('Nothing is waiting to be paid.'), findsOneWidget);
    });

    testWidgets('by default: To decide', (tester) async {
      final backend = _backend();

      await _pump(tester, WithdrawalsScreen(service: backend.server.service));

      expect(_lastList(backend)['queue'], 'ToDecide');
      expect(find.text('Withdraw Test User'), findsOneWidget);
    });

    testWidgets('a settled status opens History on that chip', (tester) async {
      final backend = _backend([
        withdrawalRow({'status': 'Failed', 'queue': 'History'}),
      ]);

      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: const WithdrawalsFilter(status: 'Failed'),
        ),
      );

      expect(_lastList(backend)['queue'], 'History');
      expect(_lastList(backend)['status'], 'Failed');
      expect(find.byKey(const ValueKey('history-chip-Failed')), findsOneWidget);
    });

    testWidgets('a status with the attention flag keeps both', (tester) async {
      final backend = _backend();

      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: const WithdrawalsFilter(
            status: 'Processing',
            needsAttentionOnly: true,
          ),
        ),
      );

      expect(_lastList(backend)['queue'], 'InProgress');
      expect(_lastList(backend)['needsAttention'], 'true');
    });
  });

  group('the buttons a card offers', () {
    testWidgets('Requested: Approve and Decline', (tester) async {
      await _pump(
        tester,
        WithdrawalsScreen(service: _backend().server.service),
      );

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Pay…'), findsNothing);
    });

    testWidgets('Approved: Pay… and nothing that moves money', (tester) async {
      final backend = _backend([
        withdrawalRow({
          'status': 'Approved',
          'approvedAt': '2026-10-11T12:31:00Z',
          'destination': upiDestination,
        }),
      ]);
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: WithdrawalsFilter.approved,
        ),
      );

      expect(find.text('Pay…'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('Approved and handed to a provider: no button at all', (
      tester,
    ) async {
      final backend = _backend([
        withdrawalRow({
          'status': 'Approved',
          'submittedAt': '2026-10-11T12:31:01Z',
          'submissionAttempts': 1,
        }),
      ]);
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: WithdrawalsFilter.approved,
        ),
      );

      expect(find.text('Pay…'), findsNothing);
      expect(
        find.textContaining('handed to the payment provider'),
        findsOneWidget,
      );
    });

    testWidgets('Processing: none; flagged Processing: Review…', (
      tester,
    ) async {
      final backend = _backend([
        withdrawalRow({
          'id': 'a',
          'status': 'Processing',
          'submittedAt': '2026-10-11T12:31:01Z',
          'submissionAttempts': 1,
        }),
        withdrawalRow({
          'id': 'b',
          'status': 'Processing',
          'needsAttention': true,
        }),
      ]);
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: const WithdrawalsFilter(status: 'Processing'),
        ),
      );

      expect(find.text('Review…'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });
  });

  group('deciding on a card', () {
    testWidgets('Approve asks first, then approves and reloads everything', (
      tester,
    ) async {
      final backend = _backend();
      var changes = 0;
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          onChanged: () => changes++,
        ),
      );
      final lists = backend.listRequests;

      await tester.tap(_buttonLabelled('Approve'));
      await _advance(tester);
      expect(find.text('Approve withdrawal'), findsOneWidget);
      expect(backend.posts, isEmpty);

      await tester.tap(_inDialog(_buttonLabelled('Approve')));
      await _advance(tester);

      expect(backend.posts.single.url.path, endsWith('/approve'));
      expect(backend.listRequests, lists + 1);
      expect(changes, 1);
      expect(
        find.text('Approved. Pay it, then open it and use Mark paid.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the question sends nothing', (tester) async {
      final backend = _backend();
      var changes = 0;
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          onChanged: () => changes++,
        ),
      );

      await tester.tap(_buttonLabelled('Approve'));
      await _advance(tester);
      await tester.tap(_inDialog(_buttonLabelled('Cancel')));
      await _advance(tester);

      expect(backend.posts, isEmpty);
      expect(changes, 0);
    });

    testWidgets('an automatic provider that paid at once says so', (
      tester,
    ) async {
      final backend = _backend()..approveOutcome = 'Completed';
      await _pump(tester, WithdrawalsScreen(service: backend.server.service));

      await tester.tap(_buttonLabelled('Approve'));
      await _advance(tester);
      await tester.tap(_inDialog(_buttonLabelled('Approve')));
      await _advance(tester);

      expect(
        find.text('Approved, and the payment provider has already paid it.'),
        findsOneWidget,
      );
    });

    testWidgets('Decline needs a reason, sends it trimmed, and reloads', (
      tester,
    ) async {
      final backend = _backend();
      var changes = 0;
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          onChanged: () => changes++,
        ),
      );

      await tester.tap(_buttonLabelled('Decline'));
      await _advance(tester);

      // An empty reason is refused and nothing is sent.
      await tester.tap(_inDialog(_buttonLabelled('Decline')));
      await _advance(tester);
      expect(find.text('Enter a reason.'), findsOneWidget);
      expect(backend.posts, isEmpty);

      await tester.enterText(
        _inDialog(find.byType(TextFormField)),
        '  Name does not match  ',
      );
      await tester.tap(_inDialog(_buttonLabelled('Decline')));
      await _advance(tester);

      final post = backend.posts.single;
      expect(post.url.path, endsWith('/reject'));
      expect(jsonDecode(post.body), {'reason': 'Name does not match'});
      expect(changes, 1);
      expect(
        find.text('Declined. The money went back to the user.'),
        findsOneWidget,
      );
    });

    testWidgets('a 409 shows the server message and looks again', (
      tester,
    ) async {
      final backend = _backend()
        ..forced['approve'] = jsonResponse({
          'message': 'Already handled.',
        }, 409);
      var changes = 0;
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          onChanged: () => changes++,
        ),
      );
      final lists = backend.listRequests;

      await tester.tap(_buttonLabelled('Approve'));
      await _advance(tester);
      await tester.tap(_inDialog(_buttonLabelled('Approve')));
      await _advance(tester);

      expect(find.text('Already handled.'), findsOneWidget);
      expect(backend.listRequests, lists + 1, reason: 'it may have changed');
      expect(changes, 1);
    });

    testWidgets('a 400 shows the message and reloads nothing', (tester) async {
      final backend = _backend()
        ..forced['reject'] = jsonResponse({'message': 'Bad reason.'}, 400);
      var changes = 0;
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          onChanged: () => changes++,
        ),
      );
      final lists = backend.listRequests;

      await tester.tap(_buttonLabelled('Decline'));
      await _advance(tester);
      await tester.enterText(_inDialog(find.byType(TextFormField)), 'x');
      await tester.tap(_inDialog(_buttonLabelled('Decline')));
      await _advance(tester);

      expect(find.text('Bad reason.'), findsOneWidget);
      expect(backend.listRequests, lists);
      expect(changes, 0);
    });

    testWidgets(
      'while it is being approved the card shows a spinner and only one request is sent',
      (tester) async {
        final backend = _backend()..holdActions = Completer<void>();
        await _pump(tester, WithdrawalsScreen(service: backend.server.service));

        await tester.tap(_buttonLabelled('Approve'));
        await _advance(tester);
        await tester.tap(_inDialog(_buttonLabelled('Approve')));
        await _advance(tester);

        expect(_buttonLabelled('Approve'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        backend.holdActions!.complete();
        await _advance(tester);

        expect(backend.posts, hasLength(1));
      },
    );
  });

  group('opening the withdrawal in full', () {
    testWidgets('tapping the card opens it, and just looking changes nothing', (
      tester,
    ) async {
      final backend = _backend();
      var changes = 0;
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          onChanged: () => changes++,
        ),
      );

      await tester.tap(find.text('Withdraw Test User'));
      await tester.pumpAndSettle();
      expect(find.byType(WithdrawalDetailDialog), findsOneWidget);

      await tester.tap(_buttonLabelled('Close'));
      await tester.pumpAndSettle();

      expect(changes, 0);
    });

    testWidgets(
      'an action in the dialog calls onChanged and reloads the page',
      (tester) async {
        final backend = _backend();
        var changes = 0;
        await _pump(
          tester,
          WithdrawalsScreen(
            service: backend.server.service,
            onChanged: () => changes++,
          ),
        );
        final lists = backend.listRequests;

        await tester.tap(find.text('Withdraw Test User'));
        await tester.pumpAndSettle();

        // The dialog's own Approve (the card behind it has one too).
        final dialog = find.byType(WithdrawalDetailDialog);
        await tester.tap(
          find.descendant(of: dialog, matching: _buttonLabelled('Approve')),
        );
        await tester.pumpAndSettle();
        await tester.tap(_inDialog(_buttonLabelled('Approve')));
        await tester.pumpAndSettle();

        expect(backend.posts.single.url.path, endsWith('/approve'));
        expect(changes, 1);
        expect(backend.listRequests, greaterThan(lists));
      },
    );

    testWidgets('Pay… opens it, and Approve on the card does not', (
      tester,
    ) async {
      final backend = _backend([
        withdrawalRow({
          'status': 'Approved',
          'approvedAt': '2026-10-11T12:31:00Z',
          'destination': upiDestination,
        }),
      ]);
      await _pump(
        tester,
        WithdrawalsScreen(
          service: backend.server.service,
          initialFilter: WithdrawalsFilter.approved,
        ),
      );

      await tester.tap(find.text('Pay…'));
      await tester.pumpAndSettle();

      expect(find.byType(WithdrawalDetailDialog), findsOneWidget);
      // The full destination, which the card never has.
      expect(find.text('testuser@okhdfc'), findsWidgets);
    });

    testWidgets('a button does not also open the card', (tester) async {
      final backend = _backend();
      await _pump(tester, WithdrawalsScreen(service: backend.server.service));

      await tester.tap(_buttonLabelled('Decline'));
      await _advance(tester);

      expect(find.byType(WithdrawalDetailDialog), findsNothing);
      expect(find.text('Decline withdrawal'), findsOneWidget);
    });
  });

  group('layout of a card', () {
    testWidgets('on a wide screen the buttons sit at the right edge', (
      tester,
    ) async {
      await _pump(
        tester,
        WithdrawalsScreen(service: _backend().server.service),
        size: const Size(1800, 1200),
      );

      final card = tester.getRect(
        find.byKey(const ValueKey('withdrawal-card-open')),
      );
      final approve = tester.getRect(find.text('Approve'));
      final decline = tester.getRect(find.text('Decline'));
      final name = tester.getRect(find.text('Withdraw Test User'));

      expect(decline.right, greaterThan(card.right - 60));
      expect(approve.left, greaterThan(name.right));
      expect(approve.center.dy, closeTo(card.center.dy, 80));
    });

    testWidgets(
      'on a phone width the buttons drop under the details and work',
      (tester) async {
        final backend = _backend();
        await _pump(
          tester,
          WithdrawalsScreen(service: backend.server.service),
          size: const Size(400, 3000),
        );

        final name = tester.getRect(find.text('Withdraw Test User'));
        final approve = tester.getRect(find.text('Approve'));
        expect(approve.top, greaterThan(name.bottom));
        expect(tester.takeException(), isNull);

        await tester.tap(_buttonLabelled('Decline'));
        await _advance(tester);
        expect(find.text('Decline withdrawal'), findsOneWidget);
      },
    );
  });

  group('copying the reference', () {
    testWidgets('puts it on the clipboard and shows a tick', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pump(
        tester,
        WithdrawalsScreen(service: _backend().server.service),
      );
      await tester.tap(find.byKey(const ValueKey('copy-reference')));
      await tester.pump();

      expect(copied, 'WD20261011K7QM2XA9PD');
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byType(WithdrawalDetailDialog), findsNothing);
    });
  });
}
