/// Friendly label + credit/debit direction for a [WalletTransaction.type]
/// raw value (backend `WalletTransactionType`: CashbackPending,
/// CashbackConfirmed, CashbackRejected, CashbackReversed — M5 will add
/// withdrawal entries). Unknown/future values fall back to a neutral entry
/// rather than crashing.
class WalletTransactionCopy {
  const WalletTransactionCopy({required this.label, required this.isCredit});

  final String label;

  /// true = money added (shown as +), false = money removed (shown as -).
  final bool isCredit;

  factory WalletTransactionCopy.forType(String rawType) {
    switch (rawType) {
      case 'CashbackPending':
        return const WalletTransactionCopy(
          label: 'Cashback pending',
          isCredit: true,
        );
      case 'CashbackConfirmed':
        return const WalletTransactionCopy(
          label: 'Cashback confirmed',
          isCredit: true,
        );
      case 'CashbackRejected':
        return const WalletTransactionCopy(
          label: 'Cashback rejected',
          isCredit: false,
        );
      case 'CashbackReversed':
        return const WalletTransactionCopy(
          label: 'Cashback reversed',
          isCredit: false,
        );
      case 'Withdrawal':
        return const WalletTransactionCopy(
          label: 'Withdrawal',
          isCredit: false,
        );
      default:
        return const WalletTransactionCopy(
          label: 'Wallet update',
          isCredit: true,
        );
    }
  }
}
