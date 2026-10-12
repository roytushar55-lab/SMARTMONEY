/// Mirrors the backend's `WithdrawalResponse`: one of the user's own
/// withdrawals. [destination] is always masked; the full bank details never
/// come back from the server.
class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.reference,
    required this.amount,
    required this.feeTotal,
    required this.userFee,
    required this.netAmount,
    required this.method,
    required this.destination,
    required this.status,
    required this.failureReason,
    required this.transactionReference,
    required this.canCancel,
    required this.requestedAt,
    required this.settledAt,
  });

  final String id;

  /// Like `WD20261011K7QM2XA9PD`; quote it when asking about a payout.
  final String reference;

  /// Taken from the wallet.
  final double amount;
  final double feeTotal;

  /// The user's share of the fee, deducted from the payout.
  final double userFee;

  /// What the user receives.
  final double netAmount;

  /// Raw backend value: `Upi` or `BankTransfer`.
  final String method;

  /// Masked, for example `ab****@okhdfc` or `HDFC0001234 ****6789`.
  final String destination;

  /// Raw backend value: Requested, Approved, Processing, Completed, Failed,
  /// Rejected or Cancelled. Display code maps it to plain words.
  final String status;

  /// Why it failed or was declined. Null otherwise.
  final String? failureReason;

  /// The bank or provider reference once paid. Null before that.
  final String? transactionReference;
  final bool canCancel;
  final DateTime requestedAt;
  final DateTime? settledAt;

  factory Withdrawal.fromJson(Map<String, dynamic> json) {
    return Withdrawal(
      id: '${json['id']}',
      reference: '${json['reference'] ?? ''}',
      amount: _asDouble(json['amount']),
      feeTotal: _asDouble(json['feeTotal']),
      userFee: _asDouble(json['userFee']),
      netAmount: _asDouble(json['netAmount']),
      method: '${json['method'] ?? ''}',
      destination: '${json['destination'] ?? ''}',
      status: '${json['status'] ?? ''}',
      failureReason: json['failureReason'] as String?,
      transactionReference: json['transactionReference'] as String?,
      canCancel: json['canCancel'] == true,
      requestedAt:
          DateTime.tryParse('${json['requestedAt']}') ?? DateTime.now(),
      settledAt: json['settledAt'] == null
          ? null
          : DateTime.tryParse('${json['settledAt']}'),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
