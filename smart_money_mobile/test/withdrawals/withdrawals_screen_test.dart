import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/app/routes/route_names.dart';
import 'package:smart_money_mobile/core/widgets/status_badge.dart';
import 'package:smart_money_mobile/features/withdrawals/data/models/withdrawal.dart';
import 'package:smart_money_mobile/features/withdrawals/presentation/screens/withdrawals_screen.dart';

import 'withdrawal_test_support.dart';

/// Pumps the history behind a launcher, with a stand-in detail route that
/// pops with [detailResult], and records what the history pops with.
Future<List<Object?>> _pump(
  WidgetTester tester,
  FakeWithdrawalServer server, {
  Object? detailResult,
  List<Object?>? openedArguments,
}) async {
  final popped = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        RouteNames.withdrawalDetails: (context) {
          openedArguments?.add(ModalRoute.of(context)!.settings.arguments);
          return Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).pop(detailResult),
              child: const Text('back from detail'),
            ),
          );
        },
      },
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => WithdrawalsScreen(service: server.service),
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

void main() {
  testWidgets('lists withdrawals newest first with plain statuses', (
    tester,
  ) async {
    final server = FakeWithdrawalServer(
      (_) async => jsonResponse(
        pageJson([
          withdrawalJson(id: 'a', amount: 500),
          withdrawalJson(id: 'b', amount: 1200, status: 'Completed'),
          withdrawalJson(id: 'c', amount: 300, status: 'Rejected'),
        ]),
      ),
    );

    await _pump(tester, server);

    expect(server.seen.single.url.query, 'page=1&pageSize=20');
    expect(find.text('₹500.00'), findsOneWidget);
    expect(find.text('₹1200.00'), findsOneWidget);
    expect(_badge('Requested'), findsOneWidget);
    expect(_badge('Paid'), findsOneWidget);
    expect(_badge('Declined'), findsOneWidget);
    expect(find.textContaining('te****@okhdfc'), findsNWidgets(3));
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('says so when there are none', (tester) async {
    final server = FakeWithdrawalServer(
      (_) async => jsonResponse(pageJson([])),
    );

    await _pump(tester, server);

    expect(find.text('No withdrawals yet'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    var fail = true;
    final server = FakeWithdrawalServer((_) async {
      if (fail) return jsonResponse({'message': 'Down for a moment.'}, 500);
      return jsonResponse(pageJson([withdrawalJson()]));
    });

    await _pump(tester, server);
    expect(find.text('Down for a moment.'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('₹500.00'), findsOneWidget);
  });

  testWidgets('loads the next page on request', (tester) async {
    final server = FakeWithdrawalServer((request) async {
      final page = request.url.queryParameters['page'];
      return jsonResponse(
        pageJson(
          [withdrawalJson(id: 'p$page', amount: page == '1' ? 500 : 700)],
          totalCount: 2,
          page: int.parse(page!),
          pageSize: 1,
        ),
      );
    });

    await _pump(tester, server);
    expect(find.text('₹500.00'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(server.seen.last.url.query, 'page=2&pageSize=20');
    expect(find.text('₹500.00'), findsOneWidget);
    expect(find.text('₹700.00'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a row opens its withdrawal', (tester) async {
    final server = FakeWithdrawalServer(
      (_) async => jsonResponse(pageJson([withdrawalJson(id: 'a')])),
    );
    final opened = <Object?>[];

    await _pump(tester, server, openedArguments: opened);
    await tester.tap(find.text('₹500.00'));
    await tester.pumpAndSettle();

    expect(opened.single, isA<Withdrawal>());
    expect((opened.single as Withdrawal).id, 'a');
  });

  testWidgets('a cancellation in the detail reloads and is passed on', (
    tester,
  ) async {
    var status = 'Requested';
    final server = FakeWithdrawalServer(
      (_) async => jsonResponse(pageJson([withdrawalJson(status: status)])),
    );

    final popped = await _pump(tester, server, detailResult: true);
    expect(_badge('Requested'), findsOneWidget);

    status = 'Cancelled';
    await tester.tap(find.text('₹500.00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('back from detail'));
    await tester.pumpAndSettle();

    expect(_badge('Cancelled'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popped, [true]);
  });

  testWidgets('just looking is passed on as nothing', (tester) async {
    final server = FakeWithdrawalServer(
      (_) async => jsonResponse(pageJson([withdrawalJson()])),
    );

    final popped = await _pump(tester, server, detailResult: null);
    await tester.tap(find.text('₹500.00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('back from detail'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(popped, [null]);
    expect(server.seen, hasLength(1));
  });
}
