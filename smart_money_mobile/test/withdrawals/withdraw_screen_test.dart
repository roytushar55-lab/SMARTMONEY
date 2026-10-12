import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/features/withdrawals/presentation/screens/withdraw_screen.dart';

import 'withdrawal_test_support.dart';

/// A field by its hint. Find it before typing: the hint goes once it fills.
Finder _field(String hint) => find.widgetWithText(TextFormField, hint);

Finder _button(String label) => find.widgetWithText(FilledButton, label);

/// Pumps the screen inside a route, so popping can be observed via [popped].
Future<List<Object?>> _pump(
  WidgetTester tester,
  FakeWithdrawalServer server,
) async {
  // Tall enough that every field is on screen: a list builds lazily, and a
  // field below the fold would not exist to type into.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final popped = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => WithdrawScreen(
                      service: server.service,
                      previewDelay: Duration.zero,
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
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

Future<void> _fillUpi(
  WidgetTester tester, {
  String amount = '500',
  String name = 'Withdraw Test User',
  String upi = 'TestUser@okhdfc',
  String password = 'secret',
}) async {
  await tester.enterText(_field('Amount to withdraw'), amount);
  await tester.pumpAndSettle();
  await tester.enterText(_field('Account holder name'), name);
  await tester.enterText(_field('UPI ID, like name@bank'), upi);
  await tester.enterText(_field('Password'), password);
  await tester.pumpAndSettle();
}

Future<void> _tapWithdraw(WidgetTester tester) async {
  final button = find.byWidgetPredicate(
    (w) =>
        w is FilledButton &&
        w.child is Text &&
        ((w.child as Text).data ?? '').startsWith('Withdraw'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('opening', () {
    testWidgets('shows the balance and the limits', (tester) async {
      final server = FakeWithdrawalServer.standard(available: 800);

      await _pump(tester, server);

      expect(server.previews.single.url.query, 'amount=0');
      expect(
        find.text('Available ₹800.00 · Min ₹250.00 · Max ₹50000.00'),
        findsOneWidget,
      );
      expect(find.text('Use full balance'), findsOneWidget);
      expect(_button('Withdraw'), findsOneWidget);
    });

    testWidgets('offers no full-balance shortcut below the minimum', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard(available: 100);

      await _pump(tester, server);

      expect(find.text('Use full balance'), findsNothing);
    });

    testWidgets('a failed balance load can be retried', (tester) async {
      var fail = true;
      final server = FakeWithdrawalServer((request) async {
        if (fail) return jsonResponse({'message': 'Down.'}, 500);
        return jsonResponse(previewJson());
      });

      await _pump(tester, server);
      expect(find.text("Couldn't load your balance."), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Available ₹800.00'), findsOneWidget);
    });
  });

  group('the live fee preview', () {
    testWidgets('shows the fee and what will arrive', (tester) async {
      final server = FakeWithdrawalServer.standard(userFee: 5.9);

      await _pump(tester, server);
      await tester.enterText(_field('Amount to withdraw'), '500');
      await tester.pumpAndSettle();

      expect(server.previews.last.url.query, 'amount=500');
      expect(find.text('Fee (your share)'), findsOneWidget);
      expect(find.text('- ₹5.90'), findsOneWidget);
      expect(find.text("You'll receive"), findsOneWidget);
      expect(find.text('₹494.10'), findsOneWidget);
      expect(_button('Withdraw ₹500.00'), findsOneWidget);
    });

    testWidgets('says "None" when there is no fee', (tester) async {
      final server = FakeWithdrawalServer.standard();

      await _pump(tester, server);
      await tester.enterText(_field('Amount to withdraw'), '500');
      await tester.pumpAndSettle();

      expect(find.text('Fee'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets("shows the server's reason when it would refuse", (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard(available: 300);

      await _pump(tester, server);
      await tester.enterText(_field('Amount to withdraw'), '500');
      await tester.pumpAndSettle();

      expect(
        find.text('Your available balance is lower than this amount.'),
        findsOneWidget,
      );
      expect(find.text("You'll receive"), findsNothing);
    });

    testWidgets('fills the amount from the full-balance shortcut', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard(available: 800);

      await _pump(tester, server);
      await tester.tap(find.text('Use full balance'));
      await tester.pumpAndSettle();

      expect(server.previews.last.url.query, 'amount=800');
      expect(_button('Withdraw ₹800.00'), findsOneWidget);
    });

    testWidgets('a preview failure does not block the form', (tester) async {
      var calls = 0;
      final server = FakeWithdrawalServer((request) async {
        calls++;
        if (calls == 1) return jsonResponse(previewJson());
        return jsonResponse({'message': 'Down.'}, 500);
      });

      await _pump(tester, server);
      await tester.enterText(_field('Amount to withdraw'), '500');
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't check the fee right now. You can still continue."),
        findsOneWidget,
      );
      expect(_button('Withdraw ₹500.00'), findsOneWidget);
    });
  });

  group('checking the form before sending', () {
    testWidgets('an empty form sends nothing and says what is missing', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard();

      await _pump(tester, server);
      await _tapWithdraw(tester);

      expect(server.posts, isEmpty);
      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(find.text("Enter the account holder's name."), findsOneWidget);
      expect(
        find.text('Enter a valid UPI ID, like name@bank.'),
        findsOneWidget,
      );
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('an amount under the minimum is refused locally', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard();

      await _pump(tester, server);
      await _fillUpi(tester, amount: '100');
      await _tapWithdraw(tester);

      expect(server.posts, isEmpty);
      expect(find.text('The minimum withdrawal is ₹250.00.'), findsOneWidget);
    });

    testWidgets('bank details are checked for shape', (tester) async {
      final server = FakeWithdrawalServer.standard();

      await _pump(tester, server);
      await tester.tap(find.text('Bank transfer'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Bank account number'), '1234');
      await tester.enterText(_field('IFSC code, like HDFC0001234'), 'HDFC');
      await _tapWithdraw(tester);

      expect(server.posts, isEmpty);
      expect(
        find.text('Enter a valid bank account number (9 to 18 digits).'),
        findsOneWidget,
      );
      expect(
        find.text('Enter a valid IFSC code, like HDFC0001234.'),
        findsOneWidget,
      );
    });
  });

  group('requesting', () {
    testWidgets('UPI: sends the details and shows the result', (tester) async {
      final server = FakeWithdrawalServer.standard(userFee: 5.9);

      final popped = await _pump(tester, server);
      await _fillUpi(tester);
      await _tapWithdraw(tester);

      final body = jsonDecode(server.posts.single.body) as Map<String, dynamic>;
      expect(body['amount'], 500);
      expect(body['method'], 'Upi');
      expect(body['beneficiaryName'], 'Withdraw Test User');
      // Lower-cased before sending, as the server would anyway.
      expect(body['upiId'], 'testuser@okhdfc');
      expect(body['bankAccountNumber'], isNull);
      expect(body['password'], 'secret');

      expect(find.text('Withdrawal requested'), findsOneWidget);
      expect(find.text('WD20261011K7QM2XA9PD'), findsOneWidget);
      expect(find.text('te****@okhdfc'), findsOneWidget);
      expect(find.text('₹494.10'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(popped, [true]);
    });

    testWidgets('bank transfer: sends the account and the IFSC upper-cased', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard();

      await _pump(tester, server);
      await tester.enterText(_field('Amount to withdraw'), '500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bank transfer'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Account holder name'), 'Withdraw Test');
      await tester.enterText(_field('Bank account number'), '123456789012');
      await tester.enterText(
        _field('IFSC code, like HDFC0001234'),
        'hdfc0001234',
      );
      await tester.enterText(_field('Password'), 'secret');
      await _tapWithdraw(tester);

      final body = jsonDecode(server.posts.single.body) as Map<String, dynamic>;
      expect(body['method'], 'BankTransfer');
      expect(body['upiId'], isNull);
      expect(body['bankAccountNumber'], '123456789012');
      expect(body['ifscCode'], 'HDFC0001234');
      expect(find.text('Withdrawal requested'), findsOneWidget);
    });

    testWidgets('the system back button after a success also reports it', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard();

      final popped = await _pump(tester, server);
      await _fillUpi(tester);
      await _tapWithdraw(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(popped, [true]);
    });

    testWidgets('a wrong password shows the server message, form intact', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard(
        onPost: (_) async =>
            jsonResponse({'message': 'Incorrect password.'}, 400),
      );

      final popped = await _pump(tester, server);
      await _fillUpi(tester, password: 'wrong');
      await _tapWithdraw(tester);

      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.text('Withdrawal requested'), findsNothing);
      expect(_button('Withdraw ₹500.00'), findsOneWidget);
      expect(popped, isEmpty);
    });

    testWidgets('a conflict shows the message and re-checks the balance', (
      tester,
    ) async {
      final server = FakeWithdrawalServer.standard(
        onPost: (_) async => jsonResponse({
          'message': 'You already have a withdrawal in progress.',
        }, 409),
      );

      await _pump(tester, server);
      await _fillUpi(tester);
      final previewsBefore = server.previews.length;
      await _tapWithdraw(tester);

      expect(
        find.text('You already have a withdrawal in progress.'),
        findsOneWidget,
      );
      // The limits (amount 0) and the typed amount are both looked up again.
      expect(server.previews.length, previewsBefore + 2);
    });

    testWidgets('leaving without requesting reports nothing', (tester) async {
      final server = FakeWithdrawalServer.standard();

      final popped = await _pump(tester, server);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(popped, [null]);
      expect(server.posts, isEmpty);
    });
  });
}
