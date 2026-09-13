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
