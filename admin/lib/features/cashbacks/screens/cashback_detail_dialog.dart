import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../../withdrawals/withdrawal_formatters.dart';
import '../cashback_approval_rules.dart';
import '../cashback_event_copy.dart';
import '../cashback_queues.dart';
import '../cashback_status_copy.dart';
import '../models/admin_cashback.dart';
import '../services/admin_cashback_api_service.dart';

/// Opens one cashback in full: the numbers, why it is where it is, and its
/// audit trail (what the network reported and what each admin decided, who
/// and why). The summary comes from the list row and shows at once; only the
/// trail is loaded.
Future<void> showCashbackDetailDialog(
  BuildContext context, {
  required AdminCashback cashback,
  required AdminCashbackApiService service,
  DateTime? now,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        CashbackDetailDialog(cashback: cashback, service: service, now: now),
  );
}

class CashbackDetailDialog extends StatefulWidget {
  const CashbackDetailDialog({
    super.key,
    required this.cashback,
    required this.service,
    this.now,
  });

  final AdminCashback cashback;
  final AdminCashbackApiService service;

  /// For tests. Defaults to the current time.
  final DateTime? now;

  @override
  State<CashbackDetailDialog> createState() => _CashbackDetailDialogState();
}

class _CashbackDetailDialogState extends State<CashbackDetailDialog> {
  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  List<AdminCashbackEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);

    try {
      final events = await widget.service.events(widget.cashback.id);
      if (!mounted) return;
      setState(() {
        _events = events;
        _state = events.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load the history. Please try again.';
        _state = ViewState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashback = widget.cashback;
    final statusCopy = CashbackStatusCopy.forStatus(cashback.status);

    return Dialog(
      backgroundColor: AdminColors.surface,
      insetPadding: const EdgeInsets.all(AdminSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.lg,
                AdminSpacing.md,
                AdminSpacing.sm,
                AdminSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cashback',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatusBadge(label: statusCopy.label, color: statusCopy.color),
                  const SizedBox(width: AdminSpacing.sm),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWhy(cashback),
                    const SizedBox(height: AdminSpacing.lg),
                    _buildDetails(cashback),
                    const SizedBox(height: AdminSpacing.lg),
                    _buildTimeline(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminSpacing.lg,
                vertical: AdminSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- why it is here ------------------------------------------------------

  Widget _buildWhy(AdminCashback cashback) {
    final queue = CashbackQueue.fromApi(cashback.queue);
    final undecided =
        cashback.status == 'Pending' ||
        cashback.status == 'AwaitingAdminReview';
    final refusal = undecided
        ? cashbackApprovalRefusal(cashback.networkStatus)
        : null;
    final due = cashbackDueText(cashback, widget.now ?? DateTime.now());

    return _Panel(
      color: (queue?.color ?? AdminColors.textMuted),
      children: [
        Wrap(
          spacing: AdminSpacing.sm,
          runSpacing: AdminSpacing.xs,
          children: [
            if (queue != null)
              StatusBadge(label: queue.label, color: queue.color),
            StatusBadge(
              label: 'Network: ${_networkWord(cashback.networkStatus)}',
              color: networkStatusColor(cashback.networkStatus),
            ),
            if (cashback.isOverdue)
              const StatusBadge(label: 'Overdue', color: AdminColors.danger),
          ],
        ),
        const SizedBox(height: AdminSpacing.sm),
        Text(
          cashbackReason(cashback),
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: AdminColors.textPrimary,
          ),
        ),
        if (refusal != null) ...[
          const SizedBox(height: AdminSpacing.xs),
          Text(
            'Approving: $refusal',
            key: const ValueKey('detail-approval-note'),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AdminColors.textSecondary,
            ),
          ),
        ],
        if (due != null) ...[
          const SizedBox(height: AdminSpacing.xs),
          Text(
            due,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: cashback.isOverdue
                  ? AdminColors.danger
                  : AdminColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  // ---- the numbers ---------------------------------------------------------

  Widget _buildDetails(AdminCashback cashback) {
    final name = cashback.userFullName.trim();

    return _Section(
      title: 'Details',
      children: [
        _Row('User', name.isEmpty ? cashback.userEmail : name),
        if (name.isNotEmpty) _Row('Email', cashback.userEmail),
        _Row('Store', cashback.storeName ?? 'Unknown store'),
        _Row(
          'Order value',
          cashback.orderAmount == null
              ? '—'
              : formatRupees(cashback.orderAmount!),
        ),
        _Row(
          'Commission',
          cashback.commissionAmount == null
              ? '—'
              : formatRupees(cashback.commissionAmount!),
        ),
        _Row('Cashback', formatRupees(cashback.cashbackAmount), strong: true),
        _Row('Created', formatDateTime(cashback.createdAt)),
        _Row('Expected by', formatDateTime(cashback.expectedConfirmationDate)),
        if (cashback.confirmedDate != null)
          _Row('Confirmed', formatDateTime(cashback.confirmedDate!)),
      ],
    );
  }

  // ---- the audit trail -----------------------------------------------------

  Widget _buildTimeline() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const _Section(
          title: 'History',
          children: [
            SizedBox(
              height: 170,
              child: LoadingView(message: 'Loading history...'),
            ),
          ],
        );
      case ViewState.error:
        return _Section(
          title: 'History',
          children: [
            SizedBox(
              height: 280,
              child: ErrorView(message: _errorMessage, onRetry: _load),
            ),
          ],
        );
      case ViewState.empty:
        return const _Section(
          title: 'History',
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: AdminSpacing.md),
              child: Text(
                'Nothing has been recorded for this cashback yet. History is '
                'kept from the moment the audit trail was introduced.',
                key: ValueKey('detail-no-history'),
                style: TextStyle(color: AdminColors.textMuted, fontSize: 13),
              ),
            ),
          ],
        );
      case ViewState.success:
        return _Section(
          title: 'History',
          children: [
            for (var i = 0; i < _events.length; i++)
              _EventTile(event: _events[i], isLast: i == _events.length - 1),
          ],
        );
    }
  }

  static String _networkWord(String networkStatus) {
    final word = networkStatus.trim().toLowerCase();
    return word.isEmpty ? 'unknown' : word;
  }
}

/// A coloured note at the top: why it is here.
class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: AdminSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.md,
            vertical: AdminSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AdminColors.bgPrimary,
            borderRadius: BorderRadius.circular(AdminRadius.input),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: AdminColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the trail: a dot in the event's colour, what happened and who
/// did it, the status change, what the network said, the reason, and when.
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.isLast});

  final AdminCashbackEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final copy = CashbackEventCopy.forType(event.type);
    final change = cashbackEventStatusChange(event);
    final facts = <String>[
      ?change,
      if (event.networkStatus != null) 'Network said ${event.networkStatus}',
      formatRupees(event.amount),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: AdminSpacing.md),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: copy.color,
                border: isLast
                    ? Border.all(
                        color: copy.color.withValues(alpha: 0.35),
                        width: 3,
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AdminSpacing.sm,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      copy.label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      cashbackEventActor(event),
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  facts.join('  ·  '),
                  style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                if (event.reason != null) ...[
                  const SizedBox(height: AdminSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: SelectableText(
                      '“${event.reason}”',
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          Text(
            formatDateTime(event.createdAt),
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 12.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
