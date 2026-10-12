import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/app/routes/route_names.dart';
import 'package:smart_money_mobile/features/wallet/presentation/screens/wallet_screen.dart';

import 'wallet_test_support.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> wallet,
  List<Map<String, dynamic>> transactions = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WalletScreen(
        service: fakeWalletService(wallet: wallet, transactions: transactions),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('held balance', () {
    testWidgets('says how much is on hold for a withdrawal', (tester) async {
      await _pump(tester, wallet: walletJson(available: 800, held: 250));

      expect(find.text('₹800.00'), findsOneWidget);
      expect(find.text('₹250.00 on hold for a withdrawal'), findsOneWidget);
    });

    testWidgets('says nothing when nothing is held', (tester) async {
      await _pump(tester, wallet: walletJson(available: 800, held: 0));

      expect(find.textContaining('on hold'), findsNothing);
    });
  });

  group('withdrawal ledger entries', () {
    testWidgets('requested is a minus, paid has no sign, returned is a plus', (
      tester,
    ) async {
      await _pump(
        tester,
        wallet: walletJson(),
        transactions: [
          transactionJson('WithdrawalRequested', amount: 500, id: 'a'),
          transactionJson('WithdrawalCompleted', amount: 500, id: 'b'),
          transactionJson('WithdrawalReleased', amount: 300, id: 'c'),
        ],
      );

      expect(find.text('Withdrawal requested'), findsOneWidget);
      expect(find.text('-₹500.00'), findsOneWidget);

      expect(find.text('Withdrawal paid'), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);

      expect(find.text('Withdrawal returned'), findsOneWidget);
      expect(find.text('+₹300.00'), findsOneWidget);

      // Nothing falls through to the old catch-all any more.
      expect(find.text('Wallet update'), findsNothing);
    });

    testWidgets('a type the app does not know is neutral', (tester) async {
      await _pump(
        tester,
        wallet: walletJson(),
        transactions: [transactionJson('FutureThing', amount: 10)],
      );

      expect(find.text('Wallet update'), findsOneWidget);
      expect(find.text('₹10.00'), findsOneWidget);
      expect(find.text('+₹10.00'), findsNothing);
    });
  });

  group('the Withdraw button', () {
    testWidgets('opens the withdraw screen and reloads when it reports a '
        'change', (tester) async {
      var walletLoads = 0;
      final service = fakeWalletService(
        wallet: walletJson(),
        onRequest: (request) {
          if (request.url.path == '/api/wallet') walletLoads++;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WalletScreen(service: service),
          routes: {
            RouteNames.withdraw: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('pretend a withdrawal was requested'),
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(walletLoads, 1);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pretend a withdrawal was requested'));
      await tester.pumpAndSettle();

      expect(walletLoads, 2);
      expect(find.text('₹1250.50'), findsOneWidget);
    });
  });

  group('the History button', () {
    testWidgets('opens the withdrawal history and reloads after a change', (
      tester,
    ) async {
      var walletLoads = 0;
      final service = fakeWalletService(
        wallet: walletJson(),
        onRequest: (request) {
          if (request.url.path == '/api/wallet') walletLoads++;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WalletScreen(service: service),
          routes: {
            RouteNames.withdrawals: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('pretend one was cancelled'),
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pretend one was cancelled'));
      await tester.pumpAndSettle();

      expect(walletLoads, 2);
      expect(find.text('Bank Account'), findsNothing);
    });
  });
}
