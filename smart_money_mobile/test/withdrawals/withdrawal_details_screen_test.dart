import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_money_mobile/core/widgets/status_badge.dart';
import 'package:smart_money_mobile/features/withdrawals/data/models/withdrawal.dart';
import 'package:smart_money_mobile/features/withdrawals/presentation/screens/withdrawal_details_screen.dart';

import 'withdrawal_test_support.dart';

/// Pumps the detail behind a launcher and records what it pops with.
Future<List<Object?>> _pump(
  WidgetTester tester,
  FakeWithdrawalServer server,
  Map<String, dynamic> initial,
) async {
  final popped = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => WithdrawalDetailsScreen(
                    withdrawal: Withdrawal.fromJson(initial),
                    service: server.service,
                  ),
                ),
              );
              popped.add(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

Finder _badge(String label) =>
    find.descendant(of: find.byType(StatusBadge), matching: find.text(label));

Finder _cancelButton() =>
    find.widgetWithText(OutlinedButton, 'Cancel withdrawal');

/// A fake that serves GET from [row] and answers cancel with [onCancel].
FakeWithdrawalServer _server(
  Map<String, dynamic> row, {
  Future<http.Response> Function()? onCancel,
}) {
  return FakeWithdrawalServer((request) async {
    if (request.method == 'POST') {
      return onCancel == null ? jsonResponse(decisionJson()) : await onCancel();
    }
    return jsonResponse(row);
  });
}

void main() {
  group('showing a withdrawal', () {
    testWidgets('a requested one: explanation, figures and cancel', (
      tester,
    ) async {
      final row = withdrawalJson(amount: 500, userFee: 5.9);
      final server = _server(row);

      await _pump(tester, server, row);

      expect(server.seen.single.url.path, endsWith('/${row['id']}'));
      expect(_badge('Requested'), findsOneWidget);
      expect(find.textContaining('You can cancel it'), findsOneWidget);
      expect(find.text('₹500.00'), findsNWidgets(2)); // header and Amount
      expect(find.text('- ₹5.90'), findsOneWidget);
      expect(find.text("You'll receive"), findsOneWidget);
      expect(find.text('₹494.10'), findsOneWidget);
      expect(find.text('te****@okhdfc'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('WD20261011K7QM2XA9PD'), findsOneWidget);
      expect(_cancelButton(), findsOneWidget);
    });

    testWidgets('a paid one: bank reference, no cancel', (tester) async {
      final row = withdrawalJson(status: 'Completed')
        ..['transactionReference'] = 'UTR123456'
        ..['settledAt'] = '2026-10-12T09:00:00Z';
      final server = _server(row);

      await _pump(tester, server, row);

      expect(_badge('Paid'), findsOneWidget);
      expect(find.text('Paid'), findsNWidgets(2)); // badge and the net row
      expect(find.text('Paid on'), findsOneWidget);
      expect(find.text('UTR123456'), findsOneWidget);
      expect(_cancelButton(), findsNothing);
    });

    testWidgets('a failed one shows the reason', (tester) async {
      final row = withdrawalJson(
        status: 'Failed',
        failureReason: 'The bank returned the payment.',
      );
      final server = _server(row);

      await _pump(tester, server, row);

      expect(_badge('Failed'), findsOneWidget);
      expect(find.text('The bank returned the payment.'), findsOneWidget);
      expect(find.textContaining('back in your wallet'), findsOneWidget);
    });

    testWidgets('the server copy wins over the one it opened with', (
      tester,
    ) async {
      final stale = withdrawalJson(status: 'Requested');
      final fresh = withdrawalJson(status: 'Approved');
      final server = _server(fresh);

      await _pump(tester, server, stale);

      expect(_badge('Approved'), findsOneWidget);
      expect(_cancelButton(), findsNothing);
    });

    testWidgets('a failed refresh keeps showing what it opened with', (
      tester,
    ) async {
      final row = withdrawalJson();
      final server = FakeWithdrawalServer(
        (_) async => jsonResponse({'message': 'Down.'}, 500),
      );

      await _pump(tester, server, row);

      expect(_badge('Requested'), findsOneWidget);
      // Header, Amount and (with no fee) "You'll receive".
      expect(find.text('₹500.00'), findsNWidgets(3));
    });
  });

  group('cancelling', () {
    testWidgets('asks first, then cancels and reports the change', (
      tester,
    ) async {
      final row = withdrawalJson();
      final server = _server(row);

      final popped = await _pump(tester, server, row);
      await tester.tap(_cancelButton());
      await tester.pumpAndSettle();

      expect(find.text('Cancel this withdrawal?'), findsOneWidget);
      expect(find.textContaining('₹500.00 will go back'), findsOneWidget);
      expect(server.posts, isEmpty);

      row['status'] = 'Cancelled';
      row['canCancel'] = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel withdrawal'));
      await tester.pumpAndSettle();

      expect(server.posts.single.url.path, endsWith('/cancel'));
      expect(find.textContaining('Withdrawal cancelled.'), findsOneWidget);
      expect(_badge('Cancelled'), findsOneWidget);
      expect(_cancelButton(), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, [true]);
    });

    testWidgets('keeping it sends nothing', (tester) async {
      final row = withdrawalJson();
      final server = _server(row);

      final popped = await _pump(tester, server, row);
      await tester.tap(_cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(server.posts, isEmpty);
      expect(_cancelButton(), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, [null]);
    });

    testWidgets('too late: shows the server message and the new status', (
      tester,
    ) async {
      final row = withdrawalJson();
      final server = _server(
        row,
        onCancel: () async {
          row['status'] = 'Approved';
          row['canCancel'] = false;
          return jsonResponse({
            'message':
                'A withdrawal can only be cancelled before it is approved.',
          }, 409);
        },
      );

      final popped = await _pump(tester, server, row);
      await tester.tap(_cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel withdrawal'));
      await tester.pumpAndSettle();

      expect(_badge('Approved'), findsOneWidget);
      expect(_cancelButton(), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, [null]);
    });

    testWidgets('a network failure leaves the button to try again', (
      tester,
    ) async {
      final row = withdrawalJson();
      final server = _server(
        row,
        onCancel: () async => jsonResponse({'message': 'Down.'}, 500),
      );

      await _pump(tester, server, row);
      await tester.tap(_cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel withdrawal'));
      await tester.pumpAndSettle();

      expect(find.text('Down.'), findsOneWidget);
      expect(_cancelButton(), findsOneWidget);
      expect(_badge('Requested'), findsOneWidget);
    });
  });
}
