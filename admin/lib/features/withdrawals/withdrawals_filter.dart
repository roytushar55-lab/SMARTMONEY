import 'package:flutter/foundation.dart';

/// What the withdrawals list shows: one status (every status when [status]
/// is null) and whether only withdrawals that need an admin's attention
/// count. The dashboard and the sidebar use it to open the list pre-filtered.
@immutable
class WithdrawalsFilter {
  const WithdrawalsFilter({this.status, this.needsAttentionOnly = false});

  /// The default view: requests waiting for an admin's decision.
  static const requested = WithdrawalsFilter(status: 'Requested');

  /// Cleared for payout but not paid yet. With the manual provider these are
  /// waiting for an admin to pay them and record the bank reference.
  static const approved = WithdrawalsFilter(status: 'Approved');

  /// Every status, only the ones flagged for an admin.
  static const needsAttention = WithdrawalsFilter(needsAttentionOnly: true);

  /// A raw status name, or null for every status.
  final String? status;
  final bool needsAttentionOnly;

  @override
  bool operator ==(Object other) =>
      other is WithdrawalsFilter &&
      other.status == status &&
      other.needsAttentionOnly == needsAttentionOnly;

  @override
  int get hashCode => Object.hash(status, needsAttentionOnly);

  @override
  String toString() =>
      'WithdrawalsFilter(status: $status, '
      'needsAttentionOnly: $needsAttentionOnly)';
}
