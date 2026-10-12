/// Mirrors the backend's `AdminCashbackListItemResponse`.
class AdminCashback {
  const AdminCashback({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userFullName,
    required this.storeName,
    required this.cashbackAmount,
    required this.status,
    required this.networkStatus,
    required this.orderAmount,
    required this.commissionAmount,
    required this.currency,
    required this.createdAt,
    required this.expectedConfirmationDate,
    required this.confirmedDate,
    this.queue = '',
    this.isOverdue = false,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String userFullName;
  final String? storeName;
  final double cashbackAmount;
  final String status;
  final String networkStatus;
  final double? orderAmount;
  final double? commissionAmount;
  final String? currency;
  final DateTime createdAt;
  final DateTime expectedConfirmationDate;
  final DateTime? confirmedDate;

  /// The work queue the server put it in (`ReadyToApprove`,
  /// `ReversalsToDecide`, `NetworkRejected`, `WaitingOnNetwork`, `History`).
  final String queue;

  /// Undecided and past its expected confirmation date.
  final bool isOverdue;

  /// The pending->available money already moved once; reject would debit
  /// the wrong bucket, so the review queue must offer reverse instead.
  bool get wasPreviouslyConfirmed => confirmedDate != null;

  factory AdminCashback.fromJson(Map<String, dynamic> json) {
    return AdminCashback(
      id: '${json['id']}',
      userId: '${json['userId']}',
      userEmail: json['userEmail'] as String? ?? '',
      userFullName: json['userFullName'] as String? ?? '',
      storeName: json['storeName'] as String?,
      cashbackAmount: _asDouble(json['cashbackAmount']),
      status: json['status'] as String? ?? '',
      networkStatus: json['networkStatus'] as String? ?? '',
      orderAmount: _asNullableDouble(json['orderAmount']),
      commissionAmount: _asNullableDouble(json['commissionAmount']),
      currency: json['currency'] as String?,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      expectedConfirmationDate:
          DateTime.tryParse('${json['expectedConfirmationDate']}') ??
          DateTime.now(),
      confirmedDate: json['confirmedDate'] == null
          ? null
          : DateTime.tryParse('${json['confirmedDate']}'),
      queue: json['queue'] as String? ?? '',
      isOverdue: json['isOverdue'] as bool? ?? false,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    return _asDouble(value);
  }
}

class AdminCashbackPage {
  const AdminCashbackPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<AdminCashback> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasNextPage => page * pageSize < totalCount;

  factory AdminCashbackPage.fromJson(Map<String, dynamic> json) {
    return AdminCashbackPage(
      items: (json['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminCashback.fromJson)
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }
}

/// Mirrors `AdminCashbackSummaryResponse`: the numbers on top of the page.
class AdminCashbackSummary {
  const AdminCashbackSummary({
    required this.readyToApprove,
    required this.reversalsToDecide,
    required this.networkRejected,
    required this.waitingOnNetwork,
    required this.history,
    required this.needsDecision,
    required this.overdue,
    required this.exposureAmount,
  });

  final int readyToApprove;
  final int reversalsToDecide;
  final int networkRejected;
  final int waitingOnNetwork;
  final int history;

  /// Ready to approve + reversals to decide + network rejected.
  final int needsDecision;

  /// Undecided and past the expected confirmation date (any queue).
  final int overdue;

  /// Confirmed cashback the network has not paid us for yet, in rupees.
  final double exposureAmount;

  factory AdminCashbackSummary.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;

    return AdminCashbackSummary(
      readyToApprove: count('readyToApprove'),
      reversalsToDecide: count('reversalsToDecide'),
      networkRejected: count('networkRejected'),
      waitingOnNetwork: count('waitingOnNetwork'),
      history: count('history'),
      needsDecision: count('needsDecision'),
      overdue: count('overdue'),
      exposureAmount: AdminCashback._asDouble(json['exposureAmount']),
    );
  }
}

/// Mirrors `CashbackDecisionResponse` — the result of an approve/reject/reverse.
class CashbackDecision {
  const CashbackDecision({
    required this.cashbackId,
    required this.status,
    required this.availableBalance,
    required this.pendingBalance,
  });

  final String cashbackId;
  final String status;
  final double availableBalance;
  final double pendingBalance;

  factory CashbackDecision.fromJson(Map<String, dynamic> json) {
    return CashbackDecision(
      cashbackId: '${json['cashbackId']}',
      status: json['status'] as String? ?? '',
      availableBalance: AdminCashback._asDouble(json['availableBalance']),
      pendingBalance: AdminCashback._asDouble(json['pendingBalance']),
    );
  }
}

/// Mirrors `CashbackEventResponse`: one line of a cashback's audit trail.
class AdminCashbackEvent {
  const AdminCashbackEvent({
    required this.id,
    required this.type,
    required this.actorName,
    required this.actorEmail,
    required this.fromStatus,
    required this.toStatus,
    required this.amount,
    required this.networkStatus,
    required this.reason,
    required this.createdAt,
  });

  final String id;

  /// Created, NetworkStatusChanged, FlaggedForReview, Approved,
  /// ApprovedByOverride, Rejected or Reversed.
  final String type;

  /// Null when the network did it, not an admin.
  final String? actorName;
  final String? actorEmail;
  final String? fromStatus;
  final String toStatus;
  final double amount;

  /// What the network said about the sale when this happened.
  final String? networkStatus;
  final String? reason;
  final DateTime createdAt;

  /// True when an admin did it (the network has no actor).
  bool get byAdmin =>
      (actorName ?? '').trim().isNotEmpty ||
      (actorEmail ?? '').trim().isNotEmpty;

  factory AdminCashbackEvent.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key] as String?;
      return value == null || value.trim().isEmpty ? null : value;
    }

    return AdminCashbackEvent(
      id: '${json['id']}',
      type: json['type'] as String? ?? '',
      actorName: text('actorName'),
      actorEmail: text('actorEmail'),
      fromStatus: text('fromStatus'),
      toStatus: json['toStatus'] as String? ?? '',
      amount: AdminCashback._asDouble(json['amount']),
      networkStatus: text('networkStatus'),
      reason: text('reason'),
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}
