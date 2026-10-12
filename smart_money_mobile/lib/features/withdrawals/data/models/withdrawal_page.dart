import 'withdrawal.dart';

/// Mirrors the backend's `WithdrawalListResponse` (`GET /api/withdrawals`):
/// one page of the user's withdrawals, newest first.
class WithdrawalPage {
  const WithdrawalPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<Withdrawal> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasNextPage => page * pageSize < totalCount;

  factory WithdrawalPage.fromJson(Map<String, dynamic> json) {
    return WithdrawalPage(
      items: (json['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Withdrawal.fromJson)
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }
}
