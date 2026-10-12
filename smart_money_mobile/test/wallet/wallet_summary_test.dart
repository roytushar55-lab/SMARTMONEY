import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/features/wallet/data/models/wallet_summary.dart';

void main() {
  test('reads the held balance', () {
    final summary = WalletSummary.fromJson({
      'availableBalance': 800,
      'pendingBalance': 50.5,
      'heldBalance': 250,
      'totalEarned': 3000,
      'totalWithdrawn': 2200,
    });

    expect(summary.availableBalance, 800);
    expect(summary.pendingBalance, 50.5);
    expect(summary.heldBalance, 250);
    expect(summary.totalEarned, 3000);
    expect(summary.totalWithdrawn, 2200);
  });

  test('an older server without heldBalance means nothing is held', () {
    final summary = WalletSummary.fromJson({
      'availableBalance': 800,
      'pendingBalance': 0,
      'totalEarned': 800,
      'totalWithdrawn': 0,
    });

    expect(summary.heldBalance, 0);
  });

  test('numbers sent as strings still parse', () {
    final summary = WalletSummary.fromJson({
      'availableBalance': '12.5',
      'pendingBalance': '0',
      'heldBalance': '7',
      'totalEarned': '12.5',
      'totalWithdrawn': 'oops',
    });

    expect(summary.availableBalance, 12.5);
    expect(summary.heldBalance, 7);
    expect(summary.totalWithdrawn, 0);
  });
}
