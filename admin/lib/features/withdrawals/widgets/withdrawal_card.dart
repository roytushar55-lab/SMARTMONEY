import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/admin_withdrawal.dart';
import '../withdrawal_actions.dart';
import '../withdrawal_formatters.dart';
import '../withdrawal_queues.dart';
import '../withdrawal_status_copy.dart';

/// One withdrawal on the page. Who and what to pay on the left, the amount in
/// the middle and the action pinned on the right; on a narrow screen the
/// amount and the buttons drop under the details. Tapping the card opens the
/// withdrawal in full.
///
/// Approve and Decline are offered right here for a Requested withdrawal. An
/// Approved one has "Pay…" which opens it in full, because only there is the
/// whole destination to copy and the bank reference to record. A flagged one
/// has "Review…".
class WithdrawalCard extends StatelessWidget {
  const WithdrawalCard({
    super.key,
    required this.withdrawal,
    required this.busy,
    required this.showQueue,
    required this.onOpen,
    required this.onApprove,
    required this.onDecline,
    this.now,
  });

  final AdminWithdrawal withdrawal;

  /// A decision on this card is in flight: show a spinner instead of buttons.
  final bool busy;

  /// Show which queue it is in (the page is not already filtered by one).
  final bool showQueue;

  /// Open the withdrawal in full.
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  /// For tests. Defaults to the current time.
  final DateTime? now;

  static const double _wideFrom = 760;

  AdminWithdrawal get _w => withdrawal;

  @override
  Widget build(BuildContext context) {
    final stale = withdrawalIsWaitingLong(_w, now: now);

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
      child: Material(
        color: AdminColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.card),
          side: BorderSide(
            color: _w.needsAttention
                ? AdminColors.warning.withValues(alpha: 0.6)
                : stale
                ? AdminColors.danger.withValues(alpha: 0.45)
                : AdminColors.border,
          ),
        ),
        child: InkWell(
          key: const ValueKey('withdrawal-card-open'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _wideFrom) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _buildDetails(stale)),
                      const SizedBox(width: AdminSpacing.lg),
                      SizedBox(
                        width: 116,
                        child: _buildAmount(CrossAxisAlignment.end),
                      ),
                      const SizedBox(width: AdminSpacing.lg),
                      SizedBox(
                        width: 170,
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
                    _buildDetails(stale),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(bool stale) {
    final queue = WithdrawalQueue.fromApi(_w.queue);
    final statusCopy = WithdrawalStatusCopy.forStatus(_w.status);
    final name = _w.userFullName.trim().isEmpty
        ? _w.userEmail
        : _w.userFullName;
    final settled = !_w.isOpen;

    final payout = <String>[
      settled
          ? formatRupees(_w.netAmount)
          : 'To pay ${formatRupees(_w.netAmount)}',
      if (_w.userFee > 0) 'after ${formatRupees(_w.userFee)} fee',
      withdrawalMethodLabel(_w.method),
      _w.destinationMasked,
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
        if (name != _w.userEmail)
          Text(
            _w.userEmail,
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
            StatusBadge(label: statusCopy.label, color: statusCopy.color),
            if (_w.needsAttention)
              const StatusBadge(
                label: 'Needs attention',
                color: AdminColors.warning,
              ),
          ],
        ),
        const SizedBox(height: AdminSpacing.sm),
        Text(
          payout.join('  ·  '),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          withdrawalReason(_w),
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AdminColors.textSecondary,
          ),
        ),
        if (_w.needsAttention) ...[
          const SizedBox(height: AdminSpacing.sm),
          _AttentionNote(text: withdrawalAttentionNote(_w)),
        ],
        const SizedBox(height: AdminSpacing.sm),
        Wrap(
          spacing: AdminSpacing.md,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ReferenceWithCopy(reference: _w.reference),
            Text(
              withdrawalAgeText(_w, now: now),
              key: const ValueKey('withdrawal-age'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: stale ? FontWeight.w700 : FontWeight.w500,
                color: stale ? AdminColors.danger : AdminColors.textMuted,
              ),
            ),
            Text(
              formatDateTime(_w.requestedAt),
              style: const TextStyle(
                fontSize: 12,
                color: AdminColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmount(CrossAxisAlignment alignment) {
    final caption = switch (_w.status) {
      'Completed' => 'paid',
      'Failed' || 'Rejected' || 'Cancelled' => 'not paid',
      _ => 'to pay',
    };

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatRupees(_w.netAmount),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AdminColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          caption,
          style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
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

    final actions = WithdrawalActions.of(_w);
    final children = <Widget>[];

    if (actions.approve) {
      children.add(
        FilledButton(
          onPressed: onApprove,
          style: FilledButton.styleFrom(
            backgroundColor: AdminColors.success,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Approve'),
        ),
      );
      if (actions.decline) {
        children.add(
          TextButton(
            onPressed: onDecline,
            style: TextButton.styleFrom(foregroundColor: AdminColors.danger),
            child: const Text('Decline'),
          ),
        );
      }
    } else if (_w.status == 'Approved' && actions.markPaid) {
      children.add(
        _outlined(
          'Pay…',
          AdminColors.statusBlue,
          onOpen,
          tooltip: 'Opens the full details to copy, then record the payment',
        ),
      );
    } else if (_w.needsAttention) {
      children.add(
        _outlined(
          'Review…',
          AdminColors.warning,
          onOpen,
          tooltip: 'Opens the full details to look into it',
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AdminSpacing.xs,
      runSpacing: AdminSpacing.xs,
      children: children,
    );
  }

  Widget _outlined(
    String label,
    Color color,
    VoidCallback onPressed, {
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// The review note or provider error, on the card so it is not missed.
class _AttentionNote extends StatelessWidget {
  const _AttentionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.md,
        vertical: AdminSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AdminColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AdminRadius.input),
        border: Border.all(color: AdminColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AdminColors.warning,
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('withdrawal-attention-note'),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AdminColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "WD2026…" with a button that copies it and shows a tick for a moment, for
/// pasting into a bank statement search.
class _ReferenceWithCopy extends StatefulWidget {
  const _ReferenceWithCopy({required this.reference});

  final String reference;

  @override
  State<_ReferenceWithCopy> createState() => _ReferenceWithCopyState();
}

class _ReferenceWithCopyState extends State<_ReferenceWithCopy> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.reference));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.reference,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          key: const ValueKey('copy-reference'),
          onTap: _copy,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              _copied ? Icons.check : Icons.copy_rounded,
              size: 14,
              color: _copied ? AdminColors.success : AdminColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
