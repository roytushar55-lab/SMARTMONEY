/// Mirrors the backend's `MyWalletResponse` (`GET /api/wallet`).
class WalletSummary {
  const WalletSummary({
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalEarned,
    required this.totalWithdrawn,
  });

  final double availableBalance;
  final double pendingBalance;
  final double totalEarned;
  final double totalWithdrawn;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      availableBalance: _asDouble(json['availableBalance']),
      pendingBalance: _asDouble(json['pendingBalance']),
      totalEarned: _asDouble(json['totalEarned']),
      totalWithdrawn: _asDouble(json['totalWithdrawn']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
