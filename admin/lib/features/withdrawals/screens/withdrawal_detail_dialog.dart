import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../models/admin_withdrawal.dart';
import '../services/admin_withdrawal_api_service.dart';
import '../withdrawal_formatters.dart';
import '../withdrawal_status_copy.dart';
import 'withdrawal_action_bar.dart';

/// Opens one withdrawal in full: where to pay it, the money, what happened
/// and when, and anything that needs attention, with the actions an admin may
/// take on it. Always loads the detail endpoint, because only that carries the
/// payout destination (the list never does, and a settled withdrawal no longer
/// has one).
///
/// [onChanged] is called whenever an action changed the withdrawal (or showed
/// it had already changed), so the list behind the dialog can reload.
Future<void> showWithdrawalDetailDialog(
  BuildContext context, {
  required String withdrawalId,
  required AdminWithdrawalApiService service,
  VoidCallback? onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => WithdrawalDetailDialog(
      withdrawalId: withdrawalId,
      service: service,
      onChanged: onChanged,
    ),
  );
}

class WithdrawalDetailDialog extends StatefulWidget {
  const WithdrawalDetailDialog({
    super.key,
    required this.withdrawalId,
    required this.service,
    this.onChanged,
  });

  final String withdrawalId;
  final AdminWithdrawalApiService service;
  final VoidCallback? onChanged;

  @override
  State<WithdrawalDetailDialog> createState() => _WithdrawalDetailDialogState();
}

class _WithdrawalDetailDialogState extends State<WithdrawalDetailDialog> {
  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  AdminWithdrawal? _withdrawal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [afterChange] reloads quietly: the current details stay on screen (and the
  /// action bar keeps its result message) until the fresh ones arrive.
  Future<void> _load({bool afterChange = false}) async {
    if (!afterChange) setState(() => _state = ViewState.loading);

    try {
      final withdrawal = await widget.service.get(widget.withdrawalId);
      if (!mounted) return;
      setState(() {
        _withdrawal = withdrawal;
        _state = ViewState.success;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = afterChange
            ? 'The change went through, but the latest details could not be '
                  'loaded. ${error.message}'
            : error.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = afterChange
            ? 'The change went through, but the latest details could not be '
                  'loaded. Please try again.'
            : 'Could not load this withdrawal. Please try again.';
        _state = ViewState.error;
      });
    }
  }

  /// An action changed the withdrawal: tell the list, then show the new state.
  Future<void> _handleChanged() async {
    widget.onChanged?.call();
    if (mounted) await _load(afterChange: true);
  }

  Widget _closeButton() => TextButton(
    onPressed: () => Navigator.of(context).pop(),
    child: const Text('Close'),
  );

  @override
  Widget build(BuildContext context) {
    final withdrawal = _withdrawal;

    return Dialog(
      backgroundColor: AdminColors.surface,
      insetPadding: const EdgeInsets.all(AdminSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(withdrawal: withdrawal),
            const Divider(height: 1, color: AdminColors.border),
            Flexible(child: _buildBody(withdrawal)),
            const Divider(height: 1, color: AdminColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminSpacing.lg,
                vertical: AdminSpacing.md,
              ),
              child: (_state == ViewState.success && withdrawal != null)
                  ? WithdrawalActionBar(
                      withdrawal: withdrawal,
                      service: widget.service,
                      onChanged: _handleChanged,
                      trailing: _closeButton(),
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: _closeButton(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AdminWithdrawal? withdrawal) {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const SizedBox(
          height: 240,
          child: LoadingView(message: 'Loading withdrawal...'),
        );
      case ViewState.error:
        return SizedBox(
          height: 280,
          child: ErrorView(message: _errorMessage, onRetry: _load),
        );
      case ViewState.empty:
      case ViewState.success:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: _Content(withdrawal: withdrawal!),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.withdrawal});

  final AdminWithdrawal? withdrawal;

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;
    final statusCopy = w == null
        ? null
        : WithdrawalStatusCopy.forStatus(w.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.md,
        AdminSpacing.sm,
        AdminSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Withdrawal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (w != null)
                  SelectableText(
                    w.reference,
                    style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          if (statusCopy != null) ...[
            StatusBadge(label: statusCopy.label, color: statusCopy.color),
            const SizedBox(width: AdminSpacing.sm),
          ],
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.withdrawal});

  final AdminWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;
    const spacer = SizedBox(height: AdminSpacing.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (w.needsAttention) ...[_AttentionBanner(withdrawal: w), spacer],
        if (w.destinationUnreadable) ...[
          const _Banner(
            color: AdminColors.danger,
            icon: Icons.lock_outline,
            title: 'The payment details cannot be read',
            message:
                'The saved bank or UPI details could not be decrypted (the '
                'encryption key may have changed). Ask the user for their '
                'details, or decline the request so the money goes back to '
                'them.',
          ),
          spacer,
        ],
        _PayToSection(withdrawal: w),
        spacer,
        _AmountsSection(withdrawal: w),
        spacer,
        _UserSection(withdrawal: w),
        spacer,
        _TimelineSection(withdrawal: w),
        if (_hasProviderDetails(w)) ...[
          spacer,
          _ProviderSection(withdrawal: w),
        ],
      ],
    );
  }

  static bool _hasProviderDetails(AdminWithdrawal w) =>
      (w.providerName ?? '').isNotEmpty ||
      (w.providerReference ?? '').isNotEmpty ||
      w.submissionAttempts > 0 ||
      (w.lastError ?? '').isNotEmpty ||
      (w.failureReason ?? '').isNotEmpty;
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.withdrawal});

  final AdminWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final note = withdrawal.reviewNote;

    return _Banner(
      color: AdminColors.warning,
      icon: Icons.warning_amber_rounded,
      title: 'This withdrawal needs attention',
      message: (note == null || note.isEmpty)
          ? 'Something does not match our records. Check the details below '
                'and with the payment provider before doing anything.'
          : note,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AdminRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final String? footer;

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
        if (footer != null) ...[
          const SizedBox(height: AdminSpacing.xs),
          Text(
            footer!,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// A label on the left and a value on the right, with an optional copy button.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.value,
    this.child,
    this.copyValue,
    this.copyTooltip,
    this.strong = false,
    this.valueColor,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;
  final Widget? child;
  final String? copyValue;
  final String? copyTooltip;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child:
                child ??
                SelectableText(
                  value!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                    color: valueColor ?? AdminColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
          ),
          if (copyValue != null)
            _CopyButton(value: copyValue!, tooltip: copyTooltip ?? 'Copy'),
        ],
      ),
    );
  }
}

/// Copies [value] and shows a tick for a moment, so the admin can see it
/// worked without a toast hidden behind the dialog.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.value, required this.tooltip});

  final String value;
  final String tooltip;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;

    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _copy,
      tooltip: _copied ? 'Copied' : widget.tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _copied ? Icons.check : Icons.copy_outlined,
        size: 18,
        color: _copied ? AdminColors.success : AdminColors.textMuted,
      ),
    );
  }
}

class _PayToSection extends StatelessWidget {
  const _PayToSection({required this.withdrawal});

  final AdminWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;
    final destination = w.destination;

    // Open and readable: everything needed to make the payment.
    if (destination != null) {
      final isUpi = destination.method == 'Upi';

      return _Section(
        title: 'Pay to',
        children: [
          _Row(
            label: 'Amount to pay',
            value: formatRupees(w.netAmount),
            strong: true,
            copyValue: w.netAmount.toStringAsFixed(2),
            copyTooltip: 'Copy amount',
          ),
          _Row(
            label: 'Method',
            value: withdrawalMethodLabel(destination.method),
          ),
          _Row(
            label: 'Account holder',
            value: destination.beneficiaryName,
            copyValue: destination.beneficiaryName,
            copyTooltip: 'Copy name',
          ),
          if (isUpi)
            _Row(
              label: 'UPI ID',
              value: destination.upiId ?? '—',
              copyValue: destination.upiId,
              copyTooltip: 'Copy UPI ID',
            )
          else ...[
            _Row(
              label: 'Account number',
              value: destination.bankAccountNumber ?? '—',
              copyValue: destination.bankAccountNumber,
              copyTooltip: 'Copy account number',
            ),
            _Row(
              label: 'IFSC',
              value: destination.ifscCode ?? '—',
              copyValue: destination.ifscCode,
              copyTooltip: 'Copy IFSC',
            ),
          ],
        ],
      );
    }

    return _Section(
      title: 'Pay to',
      footer: w.isOpen
          ? null
          : 'Full bank and UPI details are removed once a withdrawal is '
                'settled.',
      children: [
        _Row(label: 'Method', value: withdrawalMethodLabel(w.method)),
        _Row(label: 'Destination', value: w.destinationMasked),
        if (w.isOpen)
          _Row(
            label: 'Amount to pay',
            value: formatRupees(w.netAmount),
            strong: true,
          ),
      ],
    );
  }
}

class _AmountsSection extends StatelessWidget {
  const _AmountsSection({required this.withdrawal});

  final AdminWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;
    final hasFee = w.feeTotal > 0;
    final absorbed = w.feeTotal - w.userFee;

    return _Section(
      title: 'Amounts',
      footer: hasFee
          ? 'Fees are estimates made when the request was placed.'
          : null,
      children: [
        _Row(label: 'Taken from wallet', value: formatRupees(w.amount)),
        if (hasFee) ...[
          _Row(
            label: 'Fee paid by user',
            value: '− ${formatRupees(w.userFee)}',
          ),
          _Row(
            label: 'Fee covered by us',
            value: formatRupees(absorbed < 0 ? 0 : absorbed),
          ),
        ],
        _Row(
          label: 'Paid to user',
          value: formatRupees(w.netAmount),
          strong: true,
        ),
        if (w.actualProviderFee != null)
          _Row(
            label: 'Actual provider fee',
            value: formatRupees(w.actualProviderFee!),
          ),
      ],
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({required this.withdrawal});

  final AdminWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;

    return _Section(
      title: 'User',
      children: [
        _Row(
          label: 'Name',
          value: w.userFullName.isEmpty ? '—' : w.userFullName,
        ),
        _Row(
          label: 'Email',
          value: w.userEmail.isEmpty ? '—' : w.userEmail,
          copyValue: w.userEmail.isEmpty ? null : w.userEmail,
          copyTooltip: 'Copy email',
        ),
      ],
    );
  }
}

class _TimelineEvent {
  const _TimelineEvent(this.label, this.at, [this.note]);

  final String label;
  final DateTime at;
  final String? note;
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.withdrawal});

  final AdminWithdrawal withdrawal;

  /// What happened, oldest first, built only from the timestamps we have.
  static List<_TimelineEvent> eventsFor(AdminWithdrawal w) {
    final events = <_TimelineEvent>[_TimelineEvent('Requested', w.requestedAt)];

    if (w.approvedAt != null) {
      events.add(
        _TimelineEvent(
          'Approved',
          w.approvedAt!,
          w.reviewedByUserId == null ? 'automatically' : 'by an admin',
        ),
      );
    }

    if (w.submittedAt != null) {
      final provider = w.providerName;
      events.add(
        _TimelineEvent(
          'Sent to payment provider',
          w.submittedAt!,
          (provider == null || provider.isEmpty) ? null : provider,
        ),
      );
    }

    if (w.settledAt != null) {
      events.add(
        _TimelineEvent(_settledLabel(w.status), w.settledAt!, _settledNote(w)),
      );
    }

    return events;
  }

  static String _settledLabel(String status) {
    switch (status) {
      case 'Completed':
        return 'Paid';
      case 'Failed':
        return 'Failed';
      case 'Rejected':
        return 'Declined';
      case 'Cancelled':
        return 'Cancelled';
      default:
        return 'Settled';
    }
  }

  static String? _settledNote(AdminWithdrawal w) {
    switch (w.status) {
      case 'Rejected':
        return w.reviewedByUserId == null ? null : 'by an admin';
      case 'Cancelled':
        return 'by the user';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = eventsFor(withdrawal);

    return _Section(
      title: 'Timeline',
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineTile(event: events[i], isLast: i == events.length - 1),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event, required this.isLast});

  final _TimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: AdminSpacing.md),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLast ? AdminColors.primary : AdminColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: AdminSpacing.sm,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  event.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.note != null)
                  Text(
                    event.note!,
                    style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatDateTime(event.at),
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderSection extends StatelessWidget {
  const _ProviderSection({required this.withdrawal});

  final AdminWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;
    final provider = w.providerName;
    final reference = w.providerReference;
    final lastError = w.lastError;
    final failureReason = w.failureReason;

    return _Section(
      title: 'Payment',
      footer: (lastError != null && lastError.isNotEmpty)
          ? 'The provider message is for admins only. The user never sees it.'
          : null,
      children: [
        if (provider != null && provider.isNotEmpty)
          _Row(label: 'Provider', value: provider),
        if (reference != null && reference.isNotEmpty)
          _Row(
            label: 'Payment reference',
            value: reference,
            copyValue: reference,
            copyTooltip: 'Copy payment reference',
          ),
        if (w.submissionAttempts > 0)
          _Row(label: 'Send attempts', value: '${w.submissionAttempts}'),
        if (failureReason != null && failureReason.isNotEmpty)
          _Row(label: 'Reason (user sees)', value: failureReason),
        if (lastError != null && lastError.isNotEmpty)
          _Row(
            label: 'Provider message',
            value: lastError,
            valueColor: AdminColors.danger,
          ),
      ],
    );
  }
}
