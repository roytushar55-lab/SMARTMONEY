import 'package:flutter/material.dart';

import '../../core/theme/admin_colors.dart';
import 'models/admin_cashback.dart';

/// The work queues of the review page. The server decides which queue a
/// cashback is in (`AdminCashback.queue`); this only names and colours them.
enum CashbackQueue {
  readyToApprove(
    apiName: 'ReadyToApprove',
    label: 'Ready to approve',
    color: AdminColors.success,
    emptyMessage: 'Nothing is ready to approve right now.',
  ),
  reversalsToDecide(
    apiName: 'ReversalsToDecide',
    label: 'Reversals to decide',
    color: AdminColors.statusPink,
    emptyMessage: 'No confirmed cashback has been reversed by the network.',
  ),
  networkRejected(
    apiName: 'NetworkRejected',
    label: 'Network rejected',
    color: AdminColors.danger,
    emptyMessage: 'The network has not rejected anything waiting on you.',
  ),
  waitingOnNetwork(
    apiName: 'WaitingOnNetwork',
    label: 'Waiting on network',
    color: AdminColors.statusBlue,
    emptyMessage: 'Nothing is waiting on the network.',
  ),
  history(
    apiName: 'History',
    label: 'History',
    color: AdminColors.textMuted,
    emptyMessage: 'No decided cashback yet.',
  );

  const CashbackQueue({
    required this.apiName,
    required this.label,
    required this.color,
    required this.emptyMessage,
  });

  /// The value the API uses for the `queue` filter and in `AdminCashback.queue`.
  final String apiName;
  final String label;
  final Color color;
  final String emptyMessage;

  static CashbackQueue? fromApi(String value) {
    for (final queue in values) {
      if (queue.apiName == value) return queue;
    }
    return null;
  }

  /// How many cashbacks are in this queue, from the summary.
  int count(AdminCashbackSummary summary) {
    switch (this) {
      case CashbackQueue.readyToApprove:
        return summary.readyToApprove;
      case CashbackQueue.reversalsToDecide:
        return summary.reversalsToDecide;
      case CashbackQueue.networkRejected:
        return summary.networkRejected;
      case CashbackQueue.waitingOnNetwork:
        return summary.waitingOnNetwork;
      case CashbackQueue.history:
        return summary.history;
    }
  }
}

/// The decided statuses offered as chips inside History.
const List<String> kHistoryStatuses = ['Confirmed', 'Rejected', 'Reversed'];

/// Colour for the network's own word for a sale.
Color networkStatusColor(String networkStatus) {
  switch (networkStatus.trim().toLowerCase()) {
    case 'validated':
    case 'paid':
      return AdminColors.success;
    case 'pending':
      return AdminColors.statusBlue;
    case 'rejected':
    case 'cancelled':
    case 'canceled':
    case 'reversed':
      return AdminColors.danger;
    default:
      return AdminColors.textMuted;
  }
}

/// One sentence saying why this cashback is where it is and what to do.
String cashbackReason(AdminCashback cashback) {
  final network = cashback.networkStatus.trim().toLowerCase();
  final amount = '₹${cashback.cashbackAmount.toStringAsFixed(2)}';

  switch (cashback.status) {
    case 'Confirmed':
      return 'Approved. $amount went to the user\'s available balance.';
    case 'Rejected':
      return 'Rejected. Nothing was paid to the user.';
    case 'Reversed':
      return 'Reversed. The money was taken back from the user.';
    case 'PaidOut':
      return 'Paid out to the user.';
  }

  switch (CashbackQueue.fromApi(cashback.queue)) {
    case CashbackQueue.readyToApprove:
      return 'Network says $network. Safe to approve.';
    case CashbackQueue.reversalsToDecide:
      return network == 'validated' || network == 'paid'
          ? 'Already in the user\'s balance. The network sent a new update '
                '($network), so check it before reversing.'
          : 'Already in the user\'s balance, but the network now says '
                '$network. Reverse it to take the money back.';
    case CashbackQueue.networkRejected:
      return 'Network says $network. Reject it so it leaves the user\'s '
          'pending balance.';
    case CashbackQueue.waitingOnNetwork:
      return network == 'pending' || network.isEmpty
          ? 'The network still reports this as pending. The return period '
                'is not over yet.'
          : 'The network says "$network". Waiting for a final answer.';
    case CashbackQueue.history:
    case null:
      return 'Network says ${network.isEmpty ? 'nothing yet' : network}.';
  }
}

/// "Overdue by 3 days", "Due in 12 days", "Due today". Null once decided.
String? cashbackDueText(AdminCashback cashback, DateTime now) {
  final undecided =
      cashback.status == 'Pending' || cashback.status == 'AwaitingAdminReview';
  if (!undecided) return null;

  final due = cashback.expectedConfirmationDate.toUtc();
  final today = now.toUtc();
  final days = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  if (cashback.isOverdue || days < 0) {
    final late = days < 0 ? -days : 1;
    return 'Overdue by $late ${late == 1 ? 'day' : 'days'}';
  }
  if (days == 0) return 'Due today';
  return 'Due in $days ${days == 1 ? 'day' : 'days'}';
}
