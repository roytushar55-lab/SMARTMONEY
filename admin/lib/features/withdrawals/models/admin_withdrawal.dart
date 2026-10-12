/// Mirrors the backend's `AdminWithdrawalResponse`
/// (`GET /api/admin/withdrawals`, `GET /api/admin/withdrawals/{id}`).
class AdminWithdrawal {
  const AdminWithdrawal({
    required this.id,
    required this.reference,
    required this.userId,
    required this.userFullName,
    required this.userEmail,
    required this.amount,
    required this.feeTotal,
    required this.userFee,
    required this.netAmount,
    required this.method,
    required this.destinationMasked,
    required this.status,
    required this.providerName,
    required this.providerReference,
    required this.actualProviderFee,
    required this.failureReason,
    required this.lastError,
    required this.submissionAttempts,
    required this.reviewedByUserId,
    required this.reviewNote,
    required this.needsAttention,
    required this.requestedAt,
    required this.approvedAt,
    required this.submittedAt,
    required this.settledAt,
    required this.destination,
    required this.destinationUnreadable,
    this.queue = '',
  });

  final String id;

  /// Our unique id for the payout, such as `WD20261011K7QM2XA9PD`.
  final String reference;
  final String userId;
  final String userFullName;
  final String userEmail;

  /// Taken from the user's wallet.
  final double amount;

  /// The provider's estimated total fee, including tax.
  final double feeTotal;

  /// The user's share of [feeTotal], deducted from the payout.
  final double userFee;

  /// What the user receives, and so what the admin pays.
  final double netAmount;

  /// Raw backend value: `Upi` or `BankTransfer`.
  final String method;

  /// Safe to show anywhere, for example `te****@okhdfc`.
  final String destinationMasked;

  /// Raw backend value: Requested, Approved, Processing, Completed, Failed,
  /// Rejected or Cancelled.
  final String status;
  final String? providerName;

  /// The provider's id, or the bank's UTR for a manual payout.
  final String? providerReference;
  final double? actualProviderFee;

  /// Why it failed or was declined. This text is shown to the user.
  final String? failureReason;

  /// The latest provider or submission problem. Admin only; never shown to
  /// the user.
  final String? lastError;
  final int submissionAttempts;
  final String? reviewedByUserId;
  final String? reviewNote;

  /// Something does not fit our records and an admin must look.
  final bool needsAttention;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? submittedAt;
  final DateTime? settledAt;

  /// The full payout destination. Only present on the detail endpoint, and
  /// only while the withdrawal is open.
  final AdminWithdrawalDestination? destination;

  /// The withdrawal is open but its stored destination could not be read.
  final bool destinationUnreadable;

  /// The work queue the server put it in: ToDecide, ToPay, InProgress or
  /// History.
  final String queue;

  /// Requested, Approved or Processing: money is still held and the admin
  /// may still need to act.
  bool get isOpen =>
      status == 'Requested' || status == 'Approved' || status == 'Processing';

  factory AdminWithdrawal.fromJson(Map<String, dynamic> json) {
    final destination = json['destination'];

    return AdminWithdrawal(
      id: '${json['id']}',
      reference: json['reference'] as String? ?? '',
      userId: '${json['userId']}',
      userFullName: json['userFullName'] as String? ?? '',
      userEmail: json['userEmail'] as String? ?? '',
      amount: _asDouble(json['amount']),
      feeTotal: _asDouble(json['feeTotal']),
      userFee: _asDouble(json['userFee']),
      netAmount: _asDouble(json['netAmount']),
      method: json['method'] as String? ?? '',
      destinationMasked: json['destinationMasked'] as String? ?? '',
      status: json['status'] as String? ?? '',
      providerName: json['providerName'] as String?,
      providerReference: json['providerReference'] as String?,
      actualProviderFee: json['actualProviderFee'] == null
          ? null
          : _asDouble(json['actualProviderFee']),
      failureReason: json['failureReason'] as String?,
      lastError: json['lastError'] as String?,
      submissionAttempts: (json['submissionAttempts'] as num?)?.toInt() ?? 0,
      reviewedByUserId: json['reviewedByUserId'] == null
          ? null
          : '${json['reviewedByUserId']}',
      reviewNote: json['reviewNote'] as String?,
      needsAttention: json['needsAttention'] as bool? ?? false,
      requestedAt:
          DateTime.tryParse('${json['requestedAt']}') ?? DateTime.now(),
      approvedAt: _asDate(json['approvedAt']),
      submittedAt: _asDate(json['submittedAt']),
      settledAt: _asDate(json['settledAt']),
      destination: destination is Map<String, dynamic>
          ? AdminWithdrawalDestination.fromJson(destination)
          : null,
      destinationUnreadable: json['destinationUnreadable'] as bool? ?? false,
      queue: json['queue'] as String? ?? '',
    );
  }

  static DateTime? _asDate(dynamic value) =>
      value == null ? null : DateTime.tryParse('$value');

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

/// The full bank or UPI details an admin needs to pay a withdrawal. Handle
/// with care: never log it, and never keep it after the screen closes.
class AdminWithdrawalDestination {
  const AdminWithdrawalDestination({
    required this.method,
    required this.beneficiaryName,
    required this.upiId,
    required this.bankAccountNumber,
    required this.ifscCode,
  });

  /// Raw backend value: `Upi` or `BankTransfer`.
  final String method;
  final String beneficiaryName;
  final String? upiId;
  final String? bankAccountNumber;
  final String? ifscCode;

  factory AdminWithdrawalDestination.fromJson(Map<String, dynamic> json) {
    return AdminWithdrawalDestination(
      method: json['method'] as String? ?? '',
      beneficiaryName: json['beneficiaryName'] as String? ?? '',
      upiId: json['upiId'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      ifscCode: json['ifscCode'] as String?,
    );
  }
}

class AdminWithdrawalPage {
  const AdminWithdrawalPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<AdminWithdrawal> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasNextPage => page * pageSize < totalCount;

  factory AdminWithdrawalPage.fromJson(Map<String, dynamic> json) {
    return AdminWithdrawalPage(
      items: (json['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminWithdrawal.fromJson)
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }
}

/// Mirrors `WithdrawalDecisionResponse`: the result of an approve, reject,
/// mark paid, mark failed or acknowledge.
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
  final String status;
  final double availableBalance;
  final double heldBalance;

  factory WithdrawalDecision.fromJson(Map<String, dynamic> json) {
    return WithdrawalDecision(
      withdrawalId: '${json['withdrawalId']}',
      reference: json['reference'] as String? ?? '',
      status: json['status'] as String? ?? '',
      availableBalance: AdminWithdrawal._asDouble(json['availableBalance']),
      heldBalance: AdminWithdrawal._asDouble(json['heldBalance']),
    );
  }
}

/// Mirrors `AdminWithdrawalSummaryResponse`: the numbers above the list.
class AdminWithdrawalSummary {
  const AdminWithdrawalSummary({
    required this.toDecide,
    required this.toDecideAmount,
    required this.toPay,
    required this.toPayAmount,
    required this.inProgress,
    required this.history,
    required this.needsAttention,
    required this.paidLast30Days,
    required this.paidLast30DaysAmount,
  });

  /// Requested, and what those users would receive.
  final int toDecide;
  final double toDecideAmount;

  /// Approved and waiting to be paid, and what is still owed to them.
  final int toPay;
  final double toPayAmount;

  /// With a payment provider.
  final int inProgress;

  /// Paid, failed, declined or cancelled.
  final int history;

  /// Flagged for an admin, in any status.
  final int needsAttention;

  /// Paid in the last 30 days, and what users received.
  final int paidLast30Days;
  final double paidLast30DaysAmount;

  factory AdminWithdrawalSummary.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    double money(String key) => AdminWithdrawal._asDouble(json[key]);

    return AdminWithdrawalSummary(
      toDecide: count('toDecide'),
      toDecideAmount: money('toDecideAmount'),
      toPay: count('toPay'),
      toPayAmount: money('toPayAmount'),
      inProgress: count('inProgress'),
      history: count('history'),
      needsAttention: count('needsAttention'),
      paidLast30Days: count('paidLast30Days'),
      paidLast30DaysAmount: money('paidLast30DaysAmount'),
    );
  }
}
