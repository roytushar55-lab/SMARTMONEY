/// A store (and optionally category) level override of a network's global
/// cashback policy. `categoryId == null` means the override applies to every
/// category the store sells in, for that network.
class AdminCashbackRateOverride {
  const AdminCashbackRateOverride({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.categoryId,
    required this.categoryName,
    required this.userSharePercent,
    required this.confirmationWindowDays,
    required this.isActive,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String? categoryId;
  final String? categoryName;
  final double userSharePercent;
  final int confirmationWindowDays;
  final bool isActive;

  factory AdminCashbackRateOverride.fromJson(Map<String, dynamic> json) {
    return AdminCashbackRateOverride(
      id: '${json['id']}',
      storeId: '${json['storeId']}',
      storeName: json['storeName'] as String? ?? '',
      categoryId: json['categoryId'] == null ? null : '${json['categoryId']}',
      categoryName: json['categoryName'] as String?,
      userSharePercent: (json['userSharePercent'] as num?)?.toDouble() ?? 0,
      confirmationWindowDays:
          (json['confirmationWindowDays'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
