/// Which way the money went, as the user should read it.
enum WalletMoneyDirection {
  /// Money came into the spendable balance (shown as +, green).
  added,

  /// Money left the spendable balance (shown as -, red).
  removed,

  /// A bookkeeping entry that changed no spendable money, such as a payout
  /// leaving the on-hold bucket (shown without a sign, neutral).
  moved,
}

/// Friendly label + money direction for a [WalletTransaction.type] raw value
/// (backend `WalletTransactionType`: CashbackPending, CashbackConfirmed,
/// CashbackRejected, CashbackReversed, WithdrawalRequested,
/// WithdrawalCompleted, WithdrawalReleased). Unknown/future values fall back
/// to a neutral entry rather than crashing or claiming money was added.
class WalletTransactionCopy {
  const WalletTransactionCopy({required this.label, required this.direction});

  final String label;
  final WalletMoneyDirection direction;

  bool get isCredit => direction == WalletMoneyDirection.added;
  bool get isDebit => direction == WalletMoneyDirection.removed;

  factory WalletTransactionCopy.forType(String rawType) {
    switch (rawType) {
      case 'CashbackPending':
        return const WalletTransactionCopy(
          label: 'Cashback pending',
          direction: WalletMoneyDirection.added,
        );
      case 'CashbackConfirmed':
        return const WalletTransactionCopy(
          label: 'Cashback confirmed',
          direction: WalletMoneyDirection.added,
        );
      case 'CashbackRejected':
        return const WalletTransactionCopy(
          label: 'Cashback rejected',
          direction: WalletMoneyDirection.removed,
        );
      case 'CashbackReversed':
        return const WalletTransactionCopy(
          label: 'Cashback reversed',
          direction: WalletMoneyDirection.removed,
        );
      // Available -> on hold: the user's spendable money went down.
      case 'WithdrawalRequested':
        return const WalletTransactionCopy(
          label: 'Withdrawal requested',
          direction: WalletMoneyDirection.removed,
        );
      // On hold -> paid out: spendable money already went down when it was
      // requested, so showing another minus would count it twice.
      case 'WithdrawalCompleted':
        return const WalletTransactionCopy(
          label: 'Withdrawal paid',
          direction: WalletMoneyDirection.moved,
        );
      // On hold -> available: the withdrawal failed, was declined or was
      // cancelled, and the money is spendable again.
      case 'WithdrawalReleased':
        return const WalletTransactionCopy(
          label: 'Withdrawal returned',
          direction: WalletMoneyDirection.added,
        );
      default:
        return const WalletTransactionCopy(
          label: 'Wallet update',
          direction: WalletMoneyDirection.moved,
        );
    }
  }
}
