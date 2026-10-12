import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../cashback_approval_rules.dart';
import '../cashback_queues.dart';
import '../cashback_status_copy.dart';
import '../models/admin_cashback.dart';

/// One cashback on the review page. Who and where on the left, the amount in
/// the middle and the decision buttons pinned on the right; on a narrow screen
/// the amount and buttons drop under the details instead.
class CashbackCard extends StatelessWidget {
  const CashbackCard({
    super.key,
    required this.cashback,
    required this.busy,
    required this.isSuperAdmin,
    required this.showQueue,
    required this.onApprove,
    required this.onApproveAnyway,
    required this.onReject,
    required this.onReverse,
    required this.onOpen,
    this.now,
  });

  final AdminCashback cashback;

  /// A decision on this row is in flight: show a spinner instead of buttons.
  final bool busy;

  /// Only a SuperAdmin may approve against the network's status.
  final bool isSuperAdmin;

  /// Show which queue it is in (the page is not already filtered by one).
  final bool showQueue;

  final VoidCallback onApprove;
  final VoidCallback onApproveAnyway;
  final VoidCallback onReject;
  final VoidCallback onReverse;

  /// Open the cashback's details and history.
  final VoidCallback onOpen;

  /// For tests. Defaults to the current time.
  final DateTime? now;

  static const double _wideFrom = 760;

  bool get _undecided =>
      cashback.status == 'Pending' || cashback.status == 'AwaitingAdminReview';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
      // Tapping anywhere on the card opens its details; the buttons keep
      // their own taps.
      child: Material(
        color: AdminColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.card),
          side: BorderSide(
            color: cashback.isOverdue
                ? AdminColors.danger.withValues(alpha: 0.45)
                : AdminColors.border,
          ),
        ),
        child: InkWell(
          key: const ValueKey('cashback-card-open'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: _buildLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideFrom) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildDetails()),
              const SizedBox(width: AdminSpacing.lg),
              SizedBox(width: 116, child: _buildAmount(CrossAxisAlignment.end)),
              const SizedBox(width: AdminSpacing.lg),
              SizedBox(
                width: 210,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildActions(WrapAlignment.end),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetails(),
            const SizedBox(height: AdminSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAmount(CrossAxisAlignment.start),
                const SizedBox(width: AdminSpacing.lg),
                Expanded(child: _buildActions(WrapAlignment.end)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetails() {
    final queue = CashbackQueue.fromApi(cashback.queue);
    final statusCopy = CashbackStatusCopy.forStatus(cashback.status);
    final due = cashbackDueText(cashback, now ?? DateTime.now());
    final name = cashback.userFullName.trim().isEmpty
        ? cashback.userEmail
        : cashback.userFullName;

    final meta = <String>[
      cashback.storeName ?? 'Unknown store',
      if (cashback.orderAmount != null)
        'Order ₹${cashback.orderAmount!.toStringAsFixed(2)}',
      if (cashback.commissionAmount != null)
        'Commission ₹${cashback.commissionAmount!.toStringAsFixed(2)}',
      'Created ${_formatDate(cashback.createdAt)}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimary,
          ),
        ),
        if (name != cashback.userEmail)
          Text(
            cashback.userEmail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
          ),
        const SizedBox(height: AdminSpacing.sm),
        Wrap(
          spacing: AdminSpacing.sm,
          runSpacing: AdminSpacing.xs,
          children: [
            if (showQueue && queue != null)
              StatusBadge(label: queue.label, color: queue.color),
            StatusBadge(
              label: 'Network: ${_networkWord(cashback.networkStatus)}',
              color: networkStatusColor(cashback.networkStatus),
            ),
            if (!_undecided)
              StatusBadge(label: statusCopy.label, color: statusCopy.color),
            if (cashback.isOverdue)
              const StatusBadge(label: 'Overdue', color: AdminColors.danger),
          ],
        ),
        const SizedBox(height: AdminSpacing.sm),
        Text(
          cashbackReason(cashback),
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AdminColors.textSecondary,
          ),
        ),
        const SizedBox(height: AdminSpacing.xs),
        Text(
          [...meta, ?due].join('  ·  '),
          style: TextStyle(
            fontSize: 12,
            color: cashback.isOverdue
                ? AdminColors.danger
                : AdminColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildAmount(CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₹${cashback.cashbackAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AdminColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const Text(
          'cashback',
          style: TextStyle(fontSize: 11, color: AdminColors.textMuted),
        ),
        const SizedBox(height: 2),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Details',
              key: ValueKey('card-details-hint'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AdminColors.primary,
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: AdminColors.primary),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(WrapAlignment alignment) {
    if (busy) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (!_undecided) return const SizedBox.shrink();

    // Approve is only offered once the network says validated (or paid). A
    // SuperAdmin can still approve anyway, with a reason that is recorded.
    final refusal = cashbackApprovalRefusal(cashback.networkStatus);

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AdminSpacing.xs,
      runSpacing: AdminSpacing.xs,
      children: [
        if (refusal != null && isSuperAdmin)
          Tooltip(
            message: refusal,
            child: OutlinedButton(
              onPressed: onApproveAnyway,
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminColors.warning,
                side: BorderSide(
                  color: AdminColors.warning.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Approve anyway…'),
            ),
          )
        else
          Tooltip(
            message: refusal ?? '',
            child: FilledButton(
              onPressed: refusal == null ? onApprove : null,
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.success,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Approve'),
            ),
          ),
        if (cashback.wasPreviouslyConfirmed)
          TextButton(
            onPressed: onReverse,
            style: TextButton.styleFrom(foregroundColor: AdminColors.danger),
            child: const Text('Reverse'),
          )
        else
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(foregroundColor: AdminColors.danger),
            child: const Text('Reject'),
          ),
      ],
    );
  }

  static String _networkWord(String networkStatus) {
    final word = networkStatus.trim().toLowerCase();
    return word.isEmpty ? 'unknown' : word;
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
