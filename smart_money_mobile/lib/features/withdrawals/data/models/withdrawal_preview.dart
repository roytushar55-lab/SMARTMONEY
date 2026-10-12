/// Mirrors the backend's `WithdrawalPreviewResponse`
/// (`GET /api/withdrawals/preview?amount=`): what a withdrawal of [amount]
/// would cost and whether it is allowed right now. A refusal is not an
/// error: [canWithdraw] is false and [message] says why.
class WithdrawalPreview {
  const WithdrawalPreview({
    required this.amount,
    required this.feeTotal,
    required this.userFee,
    required this.netAmount,
    required this.userFeeSharePercent,
    required this.minimumAmount,
    required this.maximumAmount,
    required this.availableBalance,
    required this.canWithdraw,
    required this.message,
  });

  final double amount;
  final double feeTotal;

  /// The part of the fee the user pays, taken off the payout.
  final double userFee;

  /// What reaches the user's account.
  final double netAmount;
  final double userFeeSharePercent;
  final double minimumAmount;
  final double maximumAmount;
  final double availableBalance;
  final bool canWithdraw;

  /// Why [canWithdraw] is false. Null when it is true.
  final String? message;

  factory WithdrawalPreview.fromJson(Map<String, dynamic> json) {
    return WithdrawalPreview(
      amount: _asDouble(json['amount']),
      feeTotal: _asDouble(json['feeTotal']),
      userFee: _asDouble(json['userFee']),
      netAmount: _asDouble(json['netAmount']),
      userFeeSharePercent: _asDouble(json['userFeeSharePercent']),
      minimumAmount: _asDouble(json['minimumAmount']),
      maximumAmount: _asDouble(json['maximumAmount']),
      availableBalance: _asDouble(json['availableBalance']),
      canWithdraw: json['canWithdraw'] == true,
      message: json['message'] as String?,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
