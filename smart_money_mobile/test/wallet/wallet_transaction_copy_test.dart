import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/features/wallet/presentation/wallet_transaction_copy.dart';

void main() {
  WalletTransactionCopy copy(String type) =>
      WalletTransactionCopy.forType(type);

  test('cashback entries keep their labels and directions', () {
    expect(copy('CashbackPending').label, 'Cashback pending');
    expect(copy('CashbackPending').direction, WalletMoneyDirection.added);
    expect(copy('CashbackConfirmed').direction, WalletMoneyDirection.added);
    expect(copy('CashbackRejected').label, 'Cashback rejected');
    expect(copy('CashbackRejected').direction, WalletMoneyDirection.removed);
    expect(copy('CashbackReversed').direction, WalletMoneyDirection.removed);
  });

  test('a withdrawal request takes money out of the balance', () {
    final requested = copy('WithdrawalRequested');

    expect(requested.label, 'Withdrawal requested');
    expect(requested.direction, WalletMoneyDirection.removed);
    expect(requested.isDebit, isTrue);
  });

  test('a paid withdrawal is informational, not a second debit', () {
    final paid = copy('WithdrawalCompleted');

    expect(paid.label, 'Withdrawal paid');
    expect(paid.direction, WalletMoneyDirection.moved);
    expect(paid.isCredit, isFalse);
    expect(paid.isDebit, isFalse);
  });

  test('a released withdrawal puts the money back', () {
    final returned = copy('WithdrawalReleased');

    expect(returned.label, 'Withdrawal returned');
    expect(returned.direction, WalletMoneyDirection.added);
  });

  test('an unknown type is neutral rather than a green credit', () {
    final unknown = copy('SomethingNew');

    expect(unknown.label, 'Wallet update');
    expect(unknown.direction, WalletMoneyDirection.moved);
  });
}
