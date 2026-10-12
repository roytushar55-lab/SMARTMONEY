/// Mirrors the backend's `MyWalletResponse` (`GET /api/wallet`).
class WalletSummary {
  const WalletSummary({
    required this.availableBalance,
    required this.pendingBalance,
    this.heldBalance = 0,
    required this.totalEarned,
    required this.totalWithdrawn,
  });

  final double availableBalance;
  final double pendingBalance;

  /// Money set aside for a withdrawal that has not been paid yet. It has
  /// already left [availableBalance]; it comes back if the withdrawal fails,
  /// is declined or is cancelled.
  final double heldBalance;
  final double totalEarned;
  final double totalWithdrawn;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      availableBalance: _asDouble(json['availableBalance']),
      pendingBalance: _asDouble(json['pendingBalance']),
      heldBalance: _asDouble(json['heldBalance']),
      totalEarned: _asDouble(json['totalEarned']),
      totalWithdrawn: _asDouble(json['totalWithdrawn']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
