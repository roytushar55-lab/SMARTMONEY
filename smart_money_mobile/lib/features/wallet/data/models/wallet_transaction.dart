/// Mirrors the backend's `WalletTransactionListItemResponse`
/// (`GET /api/wallet/transactions`) — one immutable ledger entry.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.availableBalanceAfter,
    required this.pendingBalanceAfter,
    required this.createdAt,
  });

  final String id;

  /// Raw backend value (e.g. "PendingCredit", "Withdrawal"). Display code
  /// maps this to friendly copy rather than showing it directly.
  final String type;
  final double amount;
  final String? description;
  final double availableBalanceAfter;
  final double pendingBalanceAfter;
  final DateTime createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: '${json['id']}',
      type: '${json['type']}',
      amount: _asDouble(json['amount']),
      description: json['description'] as String?,
      availableBalanceAfter: _asDouble(json['availableBalanceAfter']),
      pendingBalanceAfter: _asDouble(json['pendingBalanceAfter']),
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
