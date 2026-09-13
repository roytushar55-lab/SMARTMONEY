/// Mirrors the backend's `AdminUserStatsResponse` — dashboard KPI tile data.
class AdminUserStats {
  const AdminUserStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.deactivatedUsers,
    required this.newThisWeek,
  });

  final int totalUsers;
  final int activeUsers;
  final int deactivatedUsers;
  final int newThisWeek;

  factory AdminUserStats.fromJson(Map<String, dynamic> json) {
    return AdminUserStats(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      activeUsers: (json['activeUsers'] as num?)?.toInt() ?? 0,
      deactivatedUsers: (json['deactivatedUsers'] as num?)?.toInt() ?? 0,
      newThisWeek: (json['newThisWeek'] as num?)?.toInt() ?? 0,
    );
  }
}
