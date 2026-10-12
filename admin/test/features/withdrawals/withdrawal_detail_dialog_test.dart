import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartmoney_admin/core/widgets/status_badge.dart';
import 'package:smartmoney_admin/features/withdrawals/screens/withdrawal_detail_dialog.dart';
import 'package:smartmoney_admin/features/withdrawals/screens/withdrawals_screen.dart';

import 'withdrawal_test_support.dart';

const _upi = {
  'method': 'Upi',
  'beneficiaryName': 'Withdraw Test User',
  'upiId': 'testuser@okhdfc',
  'bankAccountNumber': null,
  'ifscCode': null,
};

const _bank = {
  'method': 'BankTransfer',
  'beneficiaryName': 'Withdraw Test User',
  'upiId': null,
  'bankAccountNumber': '123456789012',
  'ifscCode': 'HDFC0001234',
};

/// What the detail endpoint returns for an open, readable UPI withdrawal.
Map<String, dynamic> _openUpi([Map<String, dynamic>? overrides]) =>
    withdrawalRow({'destination': _upi, ...?overrides});

Finder _inDialog(Finder matching) => find.descendant(
  of: find.byType(WithdrawalDetailDialog),
  matching: matching,
);

Finder _text(String text) => _inDialog(find.text(text));

/// Pumps the list screen, then taps its only row to open the detail dialog.
/// The list shows [listRow]; the detail endpoint answers with [detailRow].
Future<FakeWithdrawalServer> _openDetail(
  WidgetTester tester,
  Map<String, dynamic> detailRow, {
  Map<String, dynamic>? listRow,
  Size size = const Size(1600, 1000),
  bool settle = true,
  Future<http.Response> Function(http.Request request)? detailResponse,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = FakeWithdrawalServer((request) {
    final isDetail = request.url.path != '/api/admin/withdrawals';
    if (isDetail) {
      return detailResponse != null
          ? detailResponse(request)
          : Future.value(jsonResponse(detailRow));
    }
    return Future.value(
      jsonResponse(withdrawalPage([listRow ?? withdrawalRow()])),
    );
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: WithdrawalsScreen(service: server.service)),
    ),
  );
  await tester.pumpAndSettle();

  // In a short window the card is below the fold, so scroll the page to it.
  await tester.scrollUntilVisible(
    find.text('Withdraw Test User'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Withdraw Test User').first);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A request that is still pending must not be settled: pumpAndSettle
    // runs fake time past the client's timeout and turns it into an error.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  return server;
}

void main() {
  group('opening a withdrawal', () {
    testWidgets('a row opens the dialog and loads that withdrawal by id', (
      tester,
    ) async {
      final server = await _openDetail(
        tester,
        _openUpi({'id': 'detail-id'}),
        listRow: withdrawalRow({'id': 'detail-id'}),
      );

      expect(find.byType(WithdrawalDetailDialog), findsOneWidget);
      // The page also asks for its summary; look only at the detail request.
      final detailCalls = server.seen
          .where((r) => r.url.path.endsWith('/detail-id'))
          .toList();
      expect(detailCalls, hasLength(1));
      expect(detailCalls.single.method, 'GET');
      expect(detailCalls.single.url.path, '/api/admin/withdrawals/detail-id');
      expect(detailCalls.single.headers['Authorization'], 'Bearer tok');
      expect(find.text('Loading withdrawal...'), findsNothing);
    });

    testWidgets('shows a spinner while loading, then the details', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      await _openDetail(
        tester,
        _openUpi(),
        detailResponse: (_) => gate.future,
        settle: false,
      );

      expect(find.text('Loading withdrawal...'), findsOneWidget);
      expect(_text('Pay to'), findsNothing);

      gate.complete(jsonResponse(_openUpi()));
      await tester.pumpAndSettle();

      expect(find.text('Loading withdrawal...'), findsNothing);
      expect(_text('Pay to'), findsOneWidget);
    });

    testWidgets('the header shows the reference and the status', (
      tester,
    ) async {
      await _openDetail(tester, _openUpi({'status': 'Approved'}));

      expect(_text('Withdrawal'), findsOneWidget);
      expect(_text('WD20261011K7QM2XA9PD'), findsOneWidget);
      expect(
        _inDialog(
          find.descendant(
            of: find.byType(StatusBadge),
            matching: find.text('Approved'),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the Close button and the X both dismiss it', (tester) async {
      await _openDetail(tester, _openUpi());
      await tester.tap(_inDialog(find.text('Close')));
      await tester.pumpAndSettle();
      expect(find.byType(WithdrawalDetailDialog), findsNothing);

      await tester.tap(find.text('Withdraw Test User').first);
      await tester.pumpAndSettle();
      expect(find.byType(WithdrawalDetailDialog), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(WithdrawalDetailDialog), findsNothing);
    });

    testWidgets('an error shows the server message and can be retried', (
      tester,
    ) async {
      var fail = true;
      await _openDetail(
        tester,
        _openUpi(),
        detailResponse: (_) async => fail
            ? jsonResponse({'message': 'Withdrawal not found.'}, 404)
            : jsonResponse(_openUpi()),
      );

      expect(_text('Something went wrong'), findsOneWidget);
      expect(_text('Withdrawal not found.'), findsOneWidget);
      expect(_text('Pay to'), findsNothing);

      fail = false;
      await tester.tap(_text('Try again'));
      await tester.pumpAndSettle();

      expect(_text('Something went wrong'), findsNothing);
      expect(_text('Pay to'), findsOneWidget);
    });

    testWidgets('an unexpected response ends in an error, not a spinner', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _openUpi(),
        detailResponse: (_) async => jsonResponse([1, 2]),
      );

      expect(find.text('Loading withdrawal...'), findsNothing);
      expect(
        _text('Could not load this withdrawal. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('closing the dialog mid-load does not throw', (tester) async {
      final gate = Completer<http.Response>();
      await _openDetail(
        tester,
        _openUpi(),
        detailResponse: (_) => gate.future,
        settle: false,
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      gate.complete(jsonResponse(_openUpi()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('where to pay', () {
    testWidgets('an open UPI withdrawal shows everything needed to pay it', (
      tester,
    ) async {
      await _openDetail(tester, _openUpi());

      expect(_text('Pay to'), findsOneWidget);
      expect(_text('Amount to pay'), findsOneWidget);
      expect(_text('₹494.10'), findsWidgets);
      expect(_text('UPI'), findsOneWidget);
      expect(_text('Account holder'), findsOneWidget);
      expect(_text('Withdraw Test User'), findsWidgets);
      expect(_text('UPI ID'), findsOneWidget);
      expect(_text('testuser@okhdfc'), findsOneWidget);
      expect(_text('Account number'), findsNothing);
      expect(_text('IFSC'), findsNothing);
    });

    testWidgets('an open bank transfer shows the account number and IFSC', (
      tester,
    ) async {
      await _openDetail(
        tester,
        withdrawalRow({
          'method': 'BankTransfer',
          'destinationMasked': 'HDFC0001234 ****9012',
          'destination': _bank,
        }),
      );

      expect(_text('Bank transfer'), findsOneWidget);
      expect(_text('Account number'), findsOneWidget);
      expect(_text('123456789012'), findsOneWidget);
      expect(_text('IFSC'), findsOneWidget);
      expect(_text('HDFC0001234'), findsOneWidget);
      expect(_text('UPI ID'), findsNothing);
    });

    testWidgets('a settled withdrawal has no details, only the masked copy', (
      tester,
    ) async {
      await _openDetail(
        tester,
        withdrawalRow({
          'status': 'Completed',
          'providerReference': 'UTR123456789012',
          'approvedAt': '2026-10-11T12:31:00Z',
          'reviewedByUserId': '33333333-3333-3333-3333-333333333333',
          'settledAt': '2026-10-11T12:40:00Z',
        }),
      );

      expect(_text('testuser@okhdfc'), findsNothing);
      expect(_text('Destination'), findsOneWidget);
      expect(_inDialog(find.text('te****@okhdfc')), findsOneWidget);
      expect(
        _text(
          'Full bank and UPI details are removed once a withdrawal is settled.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Copy UPI ID'), findsNothing);
      expect(_text('Amount to pay'), findsNothing); // nothing left to pay
    });

    testWidgets('unreadable details are explained, with the masked copy', (
      tester,
    ) async {
      await _openDetail(
        tester,
        withdrawalRow({
          'status': 'Approved',
          'destinationUnreadable': true,
          'destination': null,
        }),
      );

      expect(_text('The payment details cannot be read'), findsOneWidget);
      expect(
        _inDialog(find.textContaining('could not be decrypted')),
        findsOneWidget,
      );
      expect(_inDialog(find.text('te****@okhdfc')), findsOneWidget);
      // Still open, so the amount to pay stays visible.
      expect(_text('Amount to pay'), findsOneWidget);
      expect(find.byTooltip('Copy UPI ID'), findsNothing);
    });

    testWidgets('no unreadable banner when the details are readable', (
      tester,
    ) async {
      await _openDetail(tester, _openUpi());

      expect(_text('The payment details cannot be read'), findsNothing);
    });
  });

  group('copy buttons', () {
    late List<String> copied;

    setUp(() {
      copied = [];
    });

    void mockClipboard(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
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
    }

    testWidgets('copy the UPI ID, the plain amount, the name and the email', (
      tester,
    ) async {
      mockClipboard(tester);
      await _openDetail(tester, _openUpi());

      await tester.tap(find.byTooltip('Copy UPI ID'));
      await tester.pump();
      await tester.tap(find.byTooltip('Copy amount'));
      await tester.pump();
      await tester.tap(find.byTooltip('Copy name'));
      await tester.pump();
      await tester.ensureVisible(find.byTooltip('Copy email'));
      await tester.tap(find.byTooltip('Copy email'));
      await tester.pump();

      expect(copied, [
        'testuser@okhdfc',
        '494.10', // a plain number: no rupee sign, easy to paste into a bank app
        'Withdraw Test User',
        'wd-user-1011@example.com',
      ]);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('bank details copy as plain digits and the IFSC', (
      tester,
    ) async {
      mockClipboard(tester);
      await _openDetail(
        tester,
        withdrawalRow({'method': 'BankTransfer', 'destination': _bank}),
      );

      await tester.tap(find.byTooltip('Copy account number'));
      await tester.pump();
      await tester.tap(find.byTooltip('Copy IFSC'));
      await tester.pump();

      expect(copied, ['123456789012', 'HDFC0001234']);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a tick confirms the copy, then goes back to normal', (
      tester,
    ) async {
      mockClipboard(tester);
      await _openDetail(tester, _openUpi());

      await tester.tap(find.byTooltip('Copy UPI ID'));
      await tester.pump();

      expect(find.byTooltip('Copied'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));

      expect(find.byTooltip('Copied'), findsNothing);
      expect(find.byTooltip('Copy UPI ID'), findsOneWidget);
    });

    testWidgets('the payment reference can be copied too', (tester) async {
      mockClipboard(tester);
      await _openDetail(
        tester,
        withdrawalRow({
          'status': 'Completed',
          'providerReference': 'UTR123456789012',
          'settledAt': '2026-10-11T12:40:00Z',
        }),
      );

      await tester.ensureVisible(find.byTooltip('Copy payment reference'));
      await tester.tap(find.byTooltip('Copy payment reference'));
      await tester.pump();

      expect(copied, ['UTR123456789012']);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('amounts', () {
    testWidgets('shows who pays which part of the fee', (tester) async {
      await _openDetail(
        tester,
        _openUpi({
          'amount': 500,
          'feeTotal': 11.8,
          'userFee': 4.0,
          'netAmount': 496,
        }),
      );

      expect(_text('Taken from wallet'), findsOneWidget);
      expect(_text('₹500.00'), findsOneWidget);
      expect(_text('Fee paid by user'), findsOneWidget);
      expect(_text('− ₹4.00'), findsOneWidget);
      expect(_text('Fee covered by us'), findsOneWidget);
      expect(_text('₹7.80'), findsOneWidget);
      expect(_text('Paid to user'), findsOneWidget);
      expect(
        _text('Fees are estimates made when the request was placed.'),
        findsOneWidget,
      );
    });

    testWidgets('leaves the fee rows out when there is no fee', (tester) async {
      await _openDetail(
        tester,
        _openUpi({'feeTotal': 0, 'userFee': 0, 'netAmount': 500}),
      );

      expect(_text('Fee paid by user'), findsNothing);
      expect(_text('Fee covered by us'), findsNothing);
      expect(_text('Paid to user'), findsOneWidget);
    });

    testWidgets('shows the fee the provider really charged, when known', (
      tester,
    ) async {
      await _openDetail(
        tester,
        withdrawalRow({
          'status': 'Completed',
          'actualProviderFee': 9.5,
          'settledAt': '2026-10-11T12:40:00Z',
        }),
      );

      expect(_text('Actual provider fee'), findsOneWidget);
      expect(_text('₹9.50'), findsOneWidget);
    });

    testWidgets('never shows a negative "covered by us" figure', (
      tester,
    ) async {
      // A user share above the total (should not happen) is clamped at zero.
      await _openDetail(tester, _openUpi({'feeTotal': 3, 'userFee': 5}));

      expect(_text('Fee covered by us'), findsOneWidget);
      expect(_text('₹0.00'), findsOneWidget);
    });

    testWidgets('shows the user', (tester) async {
      await _openDetail(tester, _openUpi());

      expect(_text('User'), findsOneWidget);
      expect(_text('wd-user-1011@example.com'), findsOneWidget);
    });
  });

  group('timeline', () {
    testWidgets('a new request has just the request', (tester) async {
      await _openDetail(tester, _openUpi());

      expect(_text('Timeline'), findsOneWidget);
      // The header badge and the timeline both say it.
      expect(_text('Requested'), findsNWidgets(2));
      expect(_text('Approved'), findsNothing);
      expect(_text('Paid'), findsNothing);
    });

    testWidgets('an automatic approval and a send to the provider', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _openUpi({
          'status': 'Processing',
          'approvedAt': '2026-10-11T12:31:00Z',
          'reviewedByUserId': null,
          'submittedAt': '2026-10-11T12:31:01Z',
          'providerName': 'Fake',
        }),
      );

      expect(_text('Approved'), findsOneWidget);
      expect(_text('automatically'), findsOneWidget);
      expect(_text('Sent to payment provider'), findsOneWidget);
      expect(_text('Fake'), findsWidgets);
    });

    testWidgets('an admin approval and a manual payment', (tester) async {
      await _openDetail(
        tester,
        withdrawalRow({
          'status': 'Completed',
          'approvedAt': '2026-10-11T12:31:00Z',
          'reviewedByUserId': '33333333-3333-3333-3333-333333333333',
          'settledAt': '2026-10-11T12:40:00Z',
          'providerReference': 'UTR123456789012',
        }),
      );

      expect(_text('by an admin'), findsOneWidget);
      expect(_text('Sent to payment provider'), findsNothing);
      expect(_text('Paid'), findsNWidgets(2)); // badge and timeline
      expect(_text('UTR123456789012'), findsOneWidget);
    });

    testWidgets('a cancellation says it was the user', (tester) async {
      await _openDetail(
        tester,
        withdrawalRow({
          'status': 'Cancelled',
          'settledAt': '2026-10-11T12:35:00Z',
        }),
      );

      expect(_text('Cancelled'), findsNWidgets(2)); // badge and timeline
      expect(_text('by the user'), findsOneWidget);
    });

    testWidgets('a decline says it was an admin, and shows the reason', (
      tester,
    ) async {
      await _openDetail(
        tester,
        withdrawalRow({
          'status': 'Rejected',
          'reviewedByUserId': '33333333-3333-3333-3333-333333333333',
          'failureReason': 'Name does not match the account.',
          'settledAt': '2026-10-11T12:35:00Z',
        }),
      );

      expect(_text('Declined'), findsNWidgets(2)); // badge and timeline
      expect(_text('by an admin'), findsOneWidget);
      expect(_text('Reason (user sees)'), findsOneWidget);
      expect(_text('Name does not match the account.'), findsOneWidget);
    });

    testWidgets('timestamps are shown in local time to the minute', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _openUpi({'requestedAt': '2026-10-11T12:30:57Z'}),
      );

      final local = DateTime.utc(2026, 10, 11, 12, 30, 57).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final expected =
          '${local.year}-${two(local.month)}-${two(local.day)} '
          '${two(local.hour)}:${two(local.minute)}';

      expect(_text(expected), findsOneWidget);
    });
  });

  group('needs attention', () {
    testWidgets('shows the review note, the attempts and the provider error', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _openUpi({
          'status': 'Approved',
          'needsAttention': true,
          'reviewNote':
              'Automatic retries are used up; pay manually or reject.',
          'submissionAttempts': 5,
          'providerName': 'Fake',
          'lastError': 'Fake provider: temporary outage.',
          'approvedAt': '2026-10-11T12:31:00Z',
          'submittedAt': '2026-10-11T12:31:01Z',
        }),
      );

      expect(_text('This withdrawal needs attention'), findsOneWidget);
      expect(
        _text('Automatic retries are used up; pay manually or reject.'),
        findsOneWidget,
      );
      expect(_text('Send attempts'), findsOneWidget);
      expect(_text('5'), findsOneWidget);
      expect(_text('Provider message'), findsOneWidget);
      expect(_text('Fake provider: temporary outage.'), findsOneWidget);
      expect(
        _text(
          'The provider message is for admins only. The user never sees it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to a general message without a review note', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _openUpi({'needsAttention': true, 'reviewNote': null}),
      );

      expect(_text('This withdrawal needs attention'), findsOneWidget);
      expect(
        _inDialog(find.textContaining('Something does not match our records')),
        findsOneWidget,
      );
    });

    testWidgets('no banner and no payment section for a quiet withdrawal', (
      tester,
    ) async {
      await _openDetail(tester, _openUpi());

      expect(_text('This withdrawal needs attention'), findsNothing);
      expect(_text('Payment'), findsNothing);
      expect(_text('Provider message'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('fits a narrow phone-width window without overflow', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _openUpi({
          'needsAttention': true,
          'reviewNote':
              'Automatic retries are used up; pay manually or reject.',
          'submissionAttempts': 5,
          'providerName': 'Fake',
          'lastError': 'Fake provider: temporary outage.',
          'approvedAt': '2026-10-11T12:31:00Z',
          'submittedAt': '2026-10-11T12:31:01Z',
        }),
        size: const Size(400, 800),
      );

      expect(find.byType(WithdrawalDetailDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long content scrolls inside a short window', (tester) async {
      await _openDetail(
        tester,
        _openUpi({
          'needsAttention': true,
          'reviewNote':
              'Automatic retries are used up; pay manually or reject.',
          'providerName': 'Fake',
          'lastError': 'Fake provider: temporary outage.',
          'approvedAt': '2026-10-11T12:31:00Z',
          'submittedAt': '2026-10-11T12:31:01Z',
        }),
        size: const Size(900, 420),
      );

      expect(tester.takeException(), isNull);

      // The last section is reachable by scrolling.
      await tester.scrollUntilVisible(
        _text('Provider message'),
        200,
        scrollable: _inDialog(find.byType(Scrollable)).first,
      );
      expect(_text('Provider message'), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('each row opens its own withdrawal', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final server = FakeWithdrawalServer((request) {
        if (request.url.path == '/api/admin/withdrawals') {
          return Future.value(
            jsonResponse(
              withdrawalPage([
                withdrawalRow({'id': 'first', 'userFullName': 'First Person'}),
                withdrawalRow({
                  'id': 'second',
                  'userFullName': 'Second Person',
                }),
              ]),
            ),
          );
        }
        final id = request.url.pathSegments.last;
        return Future.value(
          jsonResponse(_openUpi({'id': id, 'userFullName': '$id person'})),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WithdrawalsScreen(service: server.service)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second Person'));
      await tester.pumpAndSettle();

      expect(server.seen.last.url.path, '/api/admin/withdrawals/second');
      expect(_text('second person'), findsOneWidget);
    });

    testWidgets('closing the dialog leaves the list as it was', (tester) async {
      final server = await _openDetail(tester, _openUpi());
      final requestsBefore = server.seen.length;

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(WithdrawalsScreen), findsOneWidget);
      expect(find.text('Withdraw Test User'), findsOneWidget);
      expect(server.seen.length, requestsBefore); // read-only: no reload
    });
  });
}
