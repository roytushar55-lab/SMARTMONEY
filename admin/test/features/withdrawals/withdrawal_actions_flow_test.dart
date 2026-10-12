import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartmoney_admin/core/widgets/status_badge.dart';
import 'package:smartmoney_admin/features/withdrawals/screens/withdrawal_detail_dialog.dart';
import 'package:smartmoney_admin/features/withdrawals/screens/withdrawals_screen.dart';

import 'fake_withdrawal_backend.dart';
import 'withdrawal_test_support.dart';

const _refusedAfterSend =
    'This payout has already been sent to the payment provider, so it can '
    'no longer be declined here. It can be declined once it needs attention.';

Finder _inDialog(Finder matching) => find.descendant(
  of: find.byType(WithdrawalDetailDialog),
  matching: matching,
);

Finder _text(String text) => _inDialog(find.text(text));

/// A button in the detail dialog's footer.
/// A button with this label (matching by subtype: TextButton, FilledButton and
/// OutlinedButton are all ButtonStyleButtons, and byType matches exactly).
Finder _buttonLabelled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<ButtonStyleButton>(),
);

Finder _button(String label) => _inDialog(_buttonLabelled(label));

/// Something inside the confirm or input dialog that an action opens.
Finder _alert(Finder matching) =>
    find.descendant(of: find.byType(AlertDialog), matching: matching);

Finder _alertButton(String label) => _alert(_buttonLabelled(label));

Finder _alertField() => _alert(find.byType(TextFormField));

/// Opens the page on the tab that holds the withdrawal with the given [row]
/// overrides, then the withdrawal. The detail endpoint carries the UPI destination.
Future<FakeWithdrawalBackend> _open(
  WidgetTester tester, {
  Map<String, dynamic>? row,
  void Function(FakeWithdrawalBackend backend)? configure,
  Size size = const Size(1600, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final backend = FakeWithdrawalBackend([
    withdrawalRow({'destination': upiDestination, ...?row}),
  ]);
  configure?.call(backend);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: WithdrawalsScreen(service: backend.server.service)),
    ),
  );
  await tester.pumpAndSettle();

  await openTabFor(tester, (row?['status'] as String?) ?? 'Requested');

  await tester.tap(find.text('Withdraw Test User').first);
  await tester.pumpAndSettle();

  return backend;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps the footer button, then the matching confirm button.
Future<void> _approveAndConfirm(WidgetTester tester) async {
  await _tap(tester, _button('Approve'));
  await _tap(tester, _alertButton('Approve'));
}

void main() {
  group('which buttons are offered', () {
    testWidgets('a new request: approve, mark paid and decline', (
      tester,
    ) async {
      await _open(tester);

      expect(_button('Approve'), findsOneWidget);
      expect(_button('Mark paid'), findsOneWidget);
      expect(_button('Decline'), findsOneWidget);
      expect(_button('Mark failed'), findsNothing);
      expect(_button('Acknowledge'), findsNothing);
      expect(_button('Close'), findsOneWidget);
    });

    testWidgets('approved by hand: mark paid, mark failed and decline', (
      tester,
    ) async {
      await _open(tester, row: {'status': 'Approved'});

      expect(_button('Approve'), findsNothing);
      expect(_button('Mark paid'), findsOneWidget);
      expect(_button('Mark failed'), findsOneWidget);
      expect(_button('Decline'), findsOneWidget);
    });

    testWidgets('a payout the provider is retrying is hands off, and says so', (
      tester,
    ) async {
      await _open(
        tester,
        row: {
          'status': 'Approved',
          'submissionAttempts': 2,
          'submittedAt': '2026-10-11T12:31:01Z',
          'providerName': 'Fake',
        },
      );

      expect(_button('Approve'), findsNothing);
      expect(_button('Mark paid'), findsNothing);
      expect(_button('Mark failed'), findsNothing);
      expect(_button('Decline'), findsNothing);
      expect(_button('Close'), findsOneWidget);
      expect(
        _inDialog(find.textContaining('payment provider is handling')),
        findsOneWidget,
      );
    });

    testWidgets('once flagged, a person can step in and acknowledge', (
      tester,
    ) async {
      await _open(
        tester,
        row: {
          'status': 'Approved',
          'submissionAttempts': 5,
          'submittedAt': '2026-10-11T12:31:01Z',
          'providerName': 'Fake',
          'needsAttention': true,
        },
      );

      expect(_button('Decline'), findsOneWidget);
      expect(_button('Mark paid'), findsOneWidget);
      expect(_button('Mark failed'), findsOneWidget);
      expect(_button('Acknowledge'), findsOneWidget);
      expect(find.textContaining('payment provider is handling'), findsNothing);
    });

    testWidgets('a finished withdrawal has only Close, and no hint', (
      tester,
    ) async {
      await _open(
        tester,
        row: {
          'status': 'Completed',
          'settledAt': '2026-10-11T12:40:00Z',
          'submissionAttempts': 1,
        },
      );

      expect(_button('Close'), findsOneWidget);
      expect(_button('Approve'), findsNothing);
      expect(_button('Mark paid'), findsNothing);
      expect(find.textContaining('payment provider is handling'), findsNothing);
    });
  });

  group('approve', () {
    testWidgets('asks first, and cancelling sends nothing', (tester) async {
      final backend = await _open(tester);

      await _tap(tester, _button('Approve'));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_alert(find.text('Approve withdrawal')), findsOneWidget);
      expect(
        _alert(find.textContaining('₹494.10 for wd-user-1011@example.com')),
        findsOneWidget,
      );

      await _tap(tester, _alertButton('Cancel'));

      expect(backend.posts, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(_button('Approve'), findsOneWidget); // still a new request
    });

    testWidgets('the manual provider: approved, now pay it', (tester) async {
      final backend = await _open(tester);

      await _approveAndConfirm(tester);

      expect(backend.posts, hasLength(1));
      expect(backend.posts.single.url.path, endsWith('/approve'));
      expect(backend.posts.single.body, isEmpty);
      expect(_text('Approved. Pay it, then use Mark paid.'), findsOneWidget);

      // The dialog now shows the new state and the next steps.
      expect(
        _inDialog(
          find.descendant(
            of: find.byType(StatusBadge),
            matching: find.text('Approved'),
          ),
        ),
        findsOneWidget,
      );
      expect(_button('Approve'), findsNothing);
      expect(_button('Mark paid'), findsOneWidget);
      expect(_button('Mark failed'), findsOneWidget);
    });

    testWidgets('an automatic provider that paid at once', (tester) async {
      await _open(tester, configure: (b) => b.approveOutcome = 'Completed');

      await _approveAndConfirm(tester);

      expect(
        _text('Approved, and the payment provider has already paid it.'),
        findsOneWidget,
      );
      expect(_button('Mark paid'), findsNothing);
    });

    testWidgets('an automatic provider that accepted it', (tester) async {
      await _open(tester, configure: (b) => b.approveOutcome = 'Processing');

      await _approveAndConfirm(tester);

      expect(
        _text('Approved and sent to the payment provider.'),
        findsOneWidget,
      );
    });

    testWidgets('an automatic provider that refused it', (tester) async {
      await _open(tester, configure: (b) => b.approveOutcome = 'Failed');

      await _approveAndConfirm(tester);

      expect(
        _text(
          'Approved, but the payment provider refused it. The money went '
          'back to the user.',
        ),
        findsOneWidget,
      );
    });
  });

  group('decline', () {
    testWidgets('needs a reason, and does not send without one', (
      tester,
    ) async {
      final backend = await _open(tester);

      await _tap(tester, _button('Decline'));
      expect(_alert(find.text('Decline withdrawal')), findsOneWidget);
      expect(
        _alert(find.textContaining('goes back to the user')),
        findsOneWidget,
      );

      await _tap(tester, _alertButton('Decline'));
      expect(_alert(find.text('Enter a reason.')), findsOneWidget);
      expect(backend.posts, isEmpty);

      await tester.enterText(_alertField(), '   ');
      await _tap(tester, _alertButton('Decline'));
      expect(_alert(find.text('Enter a reason.')), findsOneWidget);
      expect(backend.posts, isEmpty);
    });

    testWidgets('sends the trimmed reason and shows the result', (
      tester,
    ) async {
      final backend = await _open(tester);

      await _tap(tester, _button('Decline'));
      await tester.enterText(_alertField(), '  Name does not match.  ');
      await _tap(tester, _alertButton('Decline'));

      expect(backend.posts, hasLength(1));
      expect(backend.posts.single.url.path, endsWith('/reject'));
      expect(backend.posts.single.body, '{"reason":"Name does not match."}');
      expect(
        _text('Declined. The money went back to the user.'),
        findsOneWidget,
      );
      // Reloaded: the user-facing reason is now on the withdrawal.
      expect(_text('Reason (user sees)'), findsOneWidget);
      expect(_text('Name does not match.'), findsOneWidget);
      expect(_button('Decline'), findsNothing);
      expect(_button('Approve'), findsNothing);
    });

    testWidgets('cancelling the reason dialog sends nothing', (tester) async {
      final backend = await _open(tester);

      await _tap(tester, _button('Decline'));
      await tester.enterText(_alertField(), 'Something');
      await _tap(tester, _alertButton('Cancel'));

      expect(backend.posts, isEmpty);
      expect(_button('Decline'), findsOneWidget);
    });
  });

  group('mark paid', () {
    testWidgets('names the amount and where it went, and needs a reference', (
      tester,
    ) async {
      final backend = await _open(tester);

      await _tap(tester, _button('Mark paid'));

      expect(_alert(find.text('Mark as paid')), findsOneWidget);
      expect(
        _alert(find.textContaining('₹494.10 to te****@okhdfc')),
        findsOneWidget,
      );
      // A new request is approved by this, and the dialog says so.
      expect(
        _alert(find.textContaining('also approves the request')),
        findsOneWidget,
      );

      await _tap(tester, _alertButton('Mark paid'));
      expect(_alert(find.text('Enter the bank reference.')), findsOneWidget);
      expect(backend.posts, isEmpty);
    });

    testWidgets('an approved one does not mention approving', (tester) async {
      await _open(tester, row: {'status': 'Approved'});

      await _tap(tester, _button('Mark paid'));

      expect(_alert(find.textContaining('also approves')), findsNothing);
    });

    testWidgets('sends the trimmed reference and shows the settled result', (
      tester,
    ) async {
      final backend = await _open(tester);

      await _tap(tester, _button('Mark paid'));
      await tester.enterText(_alertField(), '  UTR123456789012  ');
      await _tap(tester, _alertButton('Mark paid'));

      expect(backend.posts, hasLength(1));
      expect(backend.posts.single.url.path, endsWith('/mark-paid'));
      expect(
        backend.posts.single.body,
        '{"transactionReference":"UTR123456789012"}',
      );
      expect(_text('Recorded as paid.'), findsOneWidget);

      // The detail reloaded: paid, the reference kept, the details gone.
      expect(_text('UTR123456789012'), findsOneWidget);
      expect(_text('testuser@okhdfc'), findsNothing);
      expect(_button('Mark paid'), findsNothing);
      expect(_button('Decline'), findsNothing);
    });

    testWidgets('the reference is limited to 100 characters', (tester) async {
      await _open(tester);

      await _tap(tester, _button('Mark paid'));
      await tester.enterText(_alertField(), 'U' * 150);
      await tester.pump();

      final field = tester.widget<TextField>(_alert(find.byType(TextField)));
      expect(field.controller!.text.length, 100);
    });

    testWidgets('Enter submits the single-line reference', (tester) async {
      final backend = await _open(tester, row: {'status': 'Approved'});

      await _tap(tester, _button('Mark paid'));
      await tester.enterText(_alertField(), 'UTR-ENTER-1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.posts.single.body, contains('UTR-ENTER-1'));
    });
  });

  group('mark failed', () {
    testWidgets('sends the reason and returns the money', (tester) async {
      final backend = await _open(tester, row: {'status': 'Approved'});

      await _tap(tester, _button('Mark failed'));
      expect(_alert(find.text('Mark as failed')), findsOneWidget);

      await _tap(tester, _alertButton('Mark failed'));
      expect(_alert(find.text('Enter a reason.')), findsOneWidget);
      expect(backend.posts, isEmpty);

      await tester.enterText(_alertField(), 'The bank returned the payment.');
      await _tap(tester, _alertButton('Mark failed'));

      expect(backend.posts.single.url.path, endsWith('/mark-failed'));
      expect(
        backend.posts.single.body,
        '{"reason":"The bank returned the payment."}',
      );
      expect(
        _text('Recorded as failed. The money went back to the user.'),
        findsOneWidget,
      );
      expect(_text('The bank returned the payment.'), findsOneWidget);
    });
  });

  group('acknowledge', () {
    testWidgets('clears the flag after a confirmation', (tester) async {
      final backend = await _open(
        tester,
        row: {
          'status': 'Approved',
          'needsAttention': true,
          'reviewNote':
              'Automatic retries are used up; pay manually or reject.',
          'submissionAttempts': 5,
          'submittedAt': '2026-10-11T12:31:01Z',
        },
      );
      expect(_text('This withdrawal needs attention'), findsOneWidget);

      await _tap(tester, _button('Acknowledge'));
      expect(_alert(find.text('Mark as dealt with')), findsOneWidget);
      expect(_alert(find.textContaining('No money moves')), findsOneWidget);
      await _tap(tester, _alertButton('Acknowledge'));

      expect(backend.posts.single.url.path, endsWith('/acknowledge'));
      expect(backend.posts.single.body, isEmpty);
      expect(_text('Marked as dealt with.'), findsOneWidget);
      expect(_text('This withdrawal needs attention'), findsNothing);
      expect(_button('Acknowledge'), findsNothing);
    });
  });

  group('when the server says no', () {
    testWidgets('a 409 shows its message, and refreshes what we show', (
      tester,
    ) async {
      final backend = await _open(
        tester,
        configure: (b) => b.forced['reject'] = jsonResponse({
          'message': _refusedAfterSend,
        }, 409),
      );
      final lists = backend.listRequests;
      final details = backend.detailRequests;

      await _tap(tester, _button('Decline'));
      await tester.enterText(_alertField(), 'Because');
      await _tap(tester, _alertButton('Decline'));

      expect(_text(_refusedAfterSend), findsOneWidget);
      expect(backend.listRequests, lists + 1);
      expect(backend.detailRequests, details + 1);
      // Nothing is stuck: the buttons work again.
      expect(
        tester.widget<ButtonStyleButton>(_button('Decline')).onPressed,
        isNotNull,
      );
    });

    testWidgets('a 404 shows its message and refreshes', (tester) async {
      final backend = await _open(
        tester,
        configure: (b) => b.forced['approve'] = jsonResponse({
          'message': 'Withdrawal not found.',
        }, 404),
      );
      final lists = backend.listRequests;

      await _approveAndConfirm(tester);

      expect(_text('Withdrawal not found.'), findsOneWidget);
      expect(backend.listRequests, lists + 1);
    });

    testWidgets('a 400 shows its message and changes nothing', (tester) async {
      final backend = await _open(
        tester,
        configure: (b) => b.forced['reject'] = jsonResponse({
          'message': 'A reason is required.',
        }, 400),
      );
      final lists = backend.listRequests;
      final details = backend.detailRequests;

      await _tap(tester, _button('Decline'));
      await tester.enterText(_alertField(), 'x');
      await _tap(tester, _alertButton('Decline'));

      expect(_text('A reason is required.'), findsOneWidget);
      expect(backend.listRequests, lists);
      expect(backend.detailRequests, details);
    });

    testWidgets('a 403 shows its message and changes nothing', (tester) async {
      final backend = await _open(
        tester,
        configure: (b) => b.forced['approve'] = http.Response('', 403),
      );
      final lists = backend.listRequests;

      await _approveAndConfirm(tester);

      expect(find.byType(WithdrawalDetailDialog), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(backend.listRequests, lists);
    });

    testWidgets('a server error refreshes too, since it may have acted', (
      tester,
    ) async {
      final backend = await _open(
        tester,
        configure: (b) => b.forced['approve'] = http.Response('boom', 500),
      );
      final lists = backend.listRequests;

      await _approveAndConfirm(tester);

      expect(_text('Something went wrong. Please try again.'), findsOneWidget);
      expect(backend.listRequests, lists + 1);
    });

    testWidgets('an unreadable reply is an error, and we look again', (
      tester,
    ) async {
      final backend = await _open(
        tester,
        configure: (b) => b.forced['approve'] = jsonResponse([1, 2]),
      );
      final lists = backend.listRequests;

      await _approveAndConfirm(tester);

      expect(_text('Something went wrong. Please try again.'), findsOneWidget);
      expect(backend.listRequests, lists + 1);
    });

    testWidgets('the next attempt clears the old message', (tester) async {
      final backend = await _open(
        tester,
        configure: (b) => b.forced['approve'] = jsonResponse({
          'message': 'Try again later.',
        }, 409),
      );

      await _approveAndConfirm(tester);
      expect(_text('Try again later.'), findsOneWidget);

      backend.forced.remove('approve');
      await _approveAndConfirm(tester);

      expect(_text('Try again later.'), findsNothing);
      expect(_text('Approved. Pay it, then use Mark paid.'), findsOneWidget);
    });

    testWidgets('success, then a failed refresh, says so honestly', (
      tester,
    ) async {
      final backend = await _open(tester);

      // The approval works, but loading the new details afterwards fails.
      backend.detailFailure = jsonResponse({'message': 'Server busy.'}, 503);
      await _approveAndConfirm(tester);

      expect(
        _inDialog(find.textContaining('The change went through')),
        findsOneWidget,
      );
      expect(_inDialog(find.textContaining('Server busy.')), findsOneWidget);

      // Trying again shows the new state.
      backend.detailFailure = null;
      await _tap(tester, _text('Try again'));

      expect(_button('Approve'), findsNothing);
      expect(_button('Mark paid'), findsOneWidget);
    });
  });

  group('while an action is running', () {
    testWidgets('the buttons are disabled and one request is sent', (
      tester,
    ) async {
      final hold = Completer<void>();
      final backend = await _open(
        tester,
        configure: (b) => b.holdActions = hold,
      );

      await _tap(tester, _button('Approve'));
      await tester.tap(_alertButton('Approve'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (final label in ['Approve', 'Mark paid', 'Decline']) {
        expect(
          tester.widget<ButtonStyleButton>(_button(label)).onPressed,
          isNull,
          reason: label,
        );
      }
      expect(_inDialog(find.byType(CircularProgressIndicator)), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();

      expect(backend.posts, hasLength(1));
      expect(_inDialog(find.byType(CircularProgressIndicator)), findsNothing);
      expect(_text('Approved. Pay it, then use Mark paid.'), findsOneWidget);
    });

    testWidgets('closing the dialog meanwhile is safe, and the list still '
        'refreshes', (tester) async {
      final hold = Completer<void>();
      final backend = await _open(
        tester,
        configure: (b) => b.holdActions = hold,
      );
      final lists = backend.listRequests;

      await _tap(tester, _button('Approve'));
      await tester.tap(_alertButton('Approve'));
      // Let the confirm dialog finish closing before touching what is behind
      // it. An animation only starts moving on the frame after it is
      // triggered, so: one frame to start it, then enough time to finish it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(_button('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(WithdrawalDetailDialog), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(backend.listRequests, lists + 1);
    });
  });

  group('the list behind the dialog', () {
    testWidgets('reloads after an action, so the row follows its status', (
      tester,
    ) async {
      // On the Requested tab: once declined, the row no longer belongs there.
      final backend = await _open(tester);
      expect(find.text('Withdraw Test User'), findsWidgets);
      final lists = backend.listRequests;

      await _tap(tester, _button('Decline'));
      await tester.enterText(_alertField(), 'Not allowed.');
      await _tap(tester, _alertButton('Decline'));

      expect(backend.listRequests, lists + 1);

      await _tap(tester, _button('Close'));
      expect(find.text('No withdrawal is waiting for a decision.'), findsOneWidget);
    });

    testWidgets('does not reload when nothing was done', (tester) async {
      final backend = await _open(tester);
      final lists = backend.listRequests;

      await _tap(tester, _button('Decline'));
      await _tap(tester, _alertButton('Cancel'));
      await _tap(tester, _button('Close'));

      expect(backend.listRequests, lists);
    });
  });

  group('layout', () {
    testWidgets('the footer wraps on a narrow window without overflowing', (
      tester,
    ) async {
      await _open(
        tester,
        row: {
          'status': 'Approved',
          'needsAttention': true,
          'submissionAttempts': 5,
          'submittedAt': '2026-10-11T12:31:01Z',
        },
        size: const Size(380, 800),
      );

      expect(_button('Decline'), findsOneWidget);
      expect(_button('Mark paid'), findsOneWidget);
      expect(_button('Mark failed'), findsOneWidget);
      expect(_button('Acknowledge'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
