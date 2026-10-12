import 'package:flutter/material.dart';

import '../../core/formatting/money_and_dates.dart';
import '../../core/theme/admin_colors.dart';
import 'models/admin_withdrawal.dart';
import 'withdrawal_actions.dart';
import 'withdrawal_formatters.dart';
import 'withdrawal_status_copy.dart';

/// The work queues of the withdrawals page. The server decides which queue a
/// withdrawal is in (`AdminWithdrawal.queue`); this only names and colours
/// them.
enum WithdrawalQueue {
  toDecide(
    apiName: 'ToDecide',
    label: 'To decide',
    color: AdminColors.warning,
    emptyMessage: 'No withdrawal is waiting for a decision.',
  ),
  toPay(
    apiName: 'ToPay',
    label: 'To pay',
    color: AdminColors.statusBlue,
    emptyMessage: 'Nothing is waiting to be paid.',
  ),
  inProgress(
    apiName: 'InProgress',
    label: 'In progress',
    color: AdminColors.primary,
    emptyMessage: 'Nothing is with a payment provider right now.',
  ),
  history(
    apiName: 'History',
    label: 'History',
    color: AdminColors.textMuted,
    emptyMessage: 'No withdrawal has been settled yet.',
  );

  const WithdrawalQueue({
    required this.apiName,
    required this.label,
    required this.color,
    required this.emptyMessage,
  });

  /// The value the API uses for the `queue` filter and in `AdminWithdrawal.queue`.
  final String apiName;
  final String label;
  final Color color;
  final String emptyMessage;

  static WithdrawalQueue? fromApi(String value) {
    for (final queue in values) {
      if (queue.apiName == value) return queue;
    }
    return null;
  }

  /// The queue a raw status belongs to; used for dashboard links.
  static WithdrawalQueue forStatus(String status) {
    switch (status) {
      case 'Requested':
        return WithdrawalQueue.toDecide;
      case 'Approved':
        return WithdrawalQueue.toPay;
      case 'Processing':
        return WithdrawalQueue.inProgress;
      default:
        return WithdrawalQueue.history;
    }
  }

  /// How many withdrawals are in this queue, from the summary.
  int count(AdminWithdrawalSummary summary) {
    switch (this) {
      case WithdrawalQueue.toDecide:
        return summary.toDecide;
      case WithdrawalQueue.toPay:
        return summary.toPay;
      case WithdrawalQueue.inProgress:
        return summary.inProgress;
      case WithdrawalQueue.history:
        return summary.history;
    }
  }
}

/// The settled statuses offered as chips inside History.
const List<String> kWithdrawalHistoryStatuses = [
  'Completed',
  'Failed',
  'Rejected',
  'Cancelled',
];

/// A Requested or Approved withdrawal waiting this long for an admin is
/// flagged: the user is waiting for their money.
const Duration kWithdrawalStaleAfter = Duration(hours: 24);

/// One sentence saying where this withdrawal stands and what to do.
String withdrawalReason(AdminWithdrawal w) {
  final pay = formatRupees(w.netAmount);
  final reference = (w.providerReference ?? '').trim();
  final why = (w.failureReason ?? '').trim();

  switch (w.status) {
    case 'Requested':
      return 'Waiting for you. Approve to clear it for payout, or decline '
          'with a reason the user will see.';
    case 'Approved':
      return WithdrawalActions.of(w).providerOwns
          ? 'Approved and handed to the payment provider. It will update by '
                'itself.'
          : 'Approved. Pay $pay to ${w.destinationMasked} by '
                '${withdrawalMethodLabel(w.method)}, then record the bank '
                'reference.';
    case 'Processing':
      return 'With the payment provider. It will update by itself.';
    case 'Completed':
      return reference.isEmpty
          ? 'Paid $pay.'
          : 'Paid $pay. Bank reference $reference.';
    case 'Failed':
      return 'Failed. ${why.isEmpty ? 'The money went back to the user.' : why}';
    case 'Rejected':
      return 'Declined. ${why.isEmpty ? 'The money went back to the user.' : why}';
    case 'Cancelled':
      return 'Cancelled by the user. The money went back to their balance.';
    default:
      return 'Status unknown.';
  }
}

/// What to tell an admin about a flagged withdrawal: the review note, else the
/// provider's last error, else a general line.
String withdrawalAttentionNote(AdminWithdrawal w) {
  final note = (w.reviewNote ?? '').trim();
  if (note.isNotEmpty) return note;

  final error = (w.lastError ?? '').trim();
  if (error.isNotEmpty) return error;

  return 'Something does not match our records. Open it to check.';
}

/// "Requested 3 h ago", "Approved 2 days ago", "Paid 5 min ago".
String withdrawalAgeText(AdminWithdrawal w, {DateTime? now}) {
  switch (w.status) {
    case 'Requested':
      return 'Requested ${formatAgo(w.requestedAt, now: now)}';
    case 'Approved':
    case 'Processing':
      return 'Approved ${formatAgo(w.approvedAt ?? w.requestedAt, now: now)}';
    default:
      final label = WithdrawalStatusCopy.forStatus(w.status).label;
      return '$label ${formatAgo(w.settledAt ?? w.requestedAt, now: now)}';
  }
}

/// True when an admin has had this Requested or Approved withdrawal for longer
/// than [kWithdrawalStaleAfter]. Not for one a payment provider is handling.
bool withdrawalIsWaitingLong(AdminWithdrawal w, {DateTime? now}) {
  if (w.status != 'Requested' && w.status != 'Approved') return false;
  if (WithdrawalActions.of(w).providerOwns) return false;

  final since = w.status == 'Requested'
      ? w.requestedAt
      : (w.approvedAt ?? w.requestedAt);

  return (now ?? DateTime.now()).toUtc().difference(since.toUtc()) >
      kWithdrawalStaleAfter;
}
