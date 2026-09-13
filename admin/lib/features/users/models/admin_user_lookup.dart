/// Mirrors the backend's `AdminUserListItemResponse` — one row of the users list.
class AdminUserListItem {
  const AdminUserListItem({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.createdAt,
    required this.role,
    required this.isActive,
  });

  final String userId;
  final String email;
  final String fullName;
  final DateTime createdAt;
  final String role;
  final bool isActive;

  factory AdminUserListItem.fromJson(Map<String, dynamic> json) {
    return AdminUserListItem(
      userId: '${json['userId']}',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      role: json['role'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

/// A page of [AdminUserListItem]s, mirroring the shape of the cashback list
/// page response.
class AdminUserPage {
  const AdminUserPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<AdminUserListItem> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasNextPage => page * pageSize < totalCount;

  factory AdminUserPage.fromJson(Map<String, dynamic> json) {
    return AdminUserPage(
      items: (json['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminUserListItem.fromJson)
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }
}

/// One bucket of a user's lifetime cashback (pending/approved/rejected/reversed).
class CashbackStat {
  const CashbackStat({required this.count, required this.amount});

  final int count;
  final double amount;

  factory CashbackStat.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CashbackStat(count: 0, amount: 0);
    return CashbackStat(
      count: (json['count'] as num?)?.toInt() ?? 0,
      amount: _asDouble(json['amount']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

/// Mirrors the backend's `cashbackSummary` sub-object on the user detail
/// response.
class CashbackSummary {
  const CashbackSummary({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.reversed,
  });

  final CashbackStat pending;
  final CashbackStat approved;
  final CashbackStat rejected;
  final CashbackStat reversed;

  factory CashbackSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      const empty = CashbackStat(count: 0, amount: 0);
      return const CashbackSummary(
        pending: empty,
        approved: empty,
        rejected: empty,
        reversed: empty,
      );
    }
    return CashbackSummary(
      pending: CashbackStat.fromJson(json['pending'] as Map<String, dynamic>?),
      approved: CashbackStat.fromJson(
        json['approved'] as Map<String, dynamic>?,
      ),
      rejected: CashbackStat.fromJson(
        json['rejected'] as Map<String, dynamic>?,
      ),
      reversed: CashbackStat.fromJson(
        json['reversed'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// Mirrors the backend's `AdminUserDetailResponse`.
class AdminUserDetail {
  const AdminUserDetail({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.createdAt,
    required this.role,
    required this.isActive,
    required this.cashbackSummary,
    required this.lifetimeWithdrawn,
  });

  final String userId;
  final String email;
  final String fullName;
  final DateTime createdAt;
  final String role;
  final bool isActive;
  final CashbackSummary cashbackSummary;
  final double lifetimeWithdrawn;

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    return AdminUserDetail(
      userId: '${json['userId']}',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      role: json['role'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      cashbackSummary: CashbackSummary.fromJson(
        json['cashbackSummary'] as Map<String, dynamic>?,
      ),
      lifetimeWithdrawn: CashbackStat._asDouble(json['lifetimeWithdrawn']),
    );
  }

  AdminUserDetail copyWith({String? role, bool? isActive}) {
    return AdminUserDetail(
      userId: userId,
      email: email,
      fullName: fullName,
      createdAt: createdAt,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      cashbackSummary: cashbackSummary,
      lifetimeWithdrawn: lifetimeWithdrawn,
    );
  }
}
