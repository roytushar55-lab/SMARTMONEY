/// Backend `CashbackStatus` enum values, serialized as strings.
enum CashbackStatus {
  pending,
  confirmed,
  rejected,
  paidOut,
  reversed,
  awaitingAdminReview;

  static CashbackStatus fromRaw(String raw) {
    switch (raw.toLowerCase()) {
      case 'pending':
        return CashbackStatus.pending;
      case 'confirmed':
        return CashbackStatus.confirmed;
      case 'rejected':
        return CashbackStatus.rejected;
      case 'paidout':
        return CashbackStatus.paidOut;
      case 'reversed':
        return CashbackStatus.reversed;
      case 'awaitingadminreview':
        return CashbackStatus.awaitingAdminReview;
      default:
        return CashbackStatus.pending;
    }
  }
}

/// Mirrors the backend's `MyCashbackListItemResponse` (`GET /api/cashbacks`).
class CashbackItem {
  const CashbackItem({
    required this.id,
    required this.storeName,
    required this.cashbackAmount,
    required this.status,
    required this.createdAt,
    required this.expectedConfirmationDate,
    required this.confirmedDate,
  });

  final String id;
  final String? storeName;
  final double cashbackAmount;
  final CashbackStatus status;
  final DateTime createdAt;
  final DateTime expectedConfirmationDate;
  final DateTime? confirmedDate;

  factory CashbackItem.fromJson(Map<String, dynamic> json) {
    return CashbackItem(
      id: '${json['id']}',
      storeName: json['storeName'] as String?,
      cashbackAmount: _asDouble(json['cashbackAmount']),
      status: CashbackStatus.fromRaw('${json['status']}'),
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
}
