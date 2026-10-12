/// Mirrors the backend's `WithdrawalDecisionResponse`: what a cancel left
/// behind, including the wallet balances after the money came back.
class WithdrawalDecision {
  const WithdrawalDecision({
    required this.withdrawalId,
    required this.reference,
    required this.status,
    required this.availableBalance,
    required this.heldBalance,
  });

  final String withdrawalId;
  final String reference;

  /// Raw backend status after the action, for example `Cancelled`.
  final String status;
  final double availableBalance;
  final double heldBalance;

  factory WithdrawalDecision.fromJson(Map<String, dynamic> json) {
    return WithdrawalDecision(
      withdrawalId: '${json['withdrawalId']}',
      reference: '${json['reference'] ?? ''}',
      status: '${json['status'] ?? ''}',
      availableBalance: _asDouble(json['availableBalance']),
      heldBalance: _asDouble(json['heldBalance']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
