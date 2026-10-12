import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/admin_withdrawal.dart';
import '../services/admin_withdrawal_api_service.dart';
import '../withdrawal_actions.dart';
import '../withdrawal_formatters.dart';
import 'withdrawal_input_dialog.dart';

/// The buttons at the bottom of the detail dialog: approve, decline, mark paid,
/// mark failed and acknowledge, limited to what [WithdrawalActions] says makes
/// sense for this withdrawal. Every action asks for confirmation first, and
/// reasons and bank references are collected before anything is sent.
///
/// Results appear in a banner inside the dialog (a snackbar would sit behind
/// the dialog's barrier). The server's own words are used whenever it refuses.
class WithdrawalActionBar extends StatefulWidget {
  const WithdrawalActionBar({
    super.key,
    required this.withdrawal,
    required this.service,
    required this.onChanged,
    required this.trailing,
  });

  final AdminWithdrawal withdrawal;
  final AdminWithdrawalApiService service;

  /// Called after an action succeeded, and after an error that leaves it
  /// unclear whether the withdrawal changed (a conflict, a timeout, an
  /// unreadable reply), so the caller can reload. Not called when the request
  /// was plainly refused (400, 401, 403) or cancelled. May be called after this
  /// bar was disposed.
  final Future<void> Function() onChanged;

  /// Shown at the end of the row: the dialog's Close button.
  final Widget trailing;

  @override
  State<WithdrawalActionBar> createState() => _WithdrawalActionBarState();
}

class _Notice {
  const _Notice(this.text, {required this.isError});

  final String text;
  final bool isError;
}

class _WithdrawalActionBarState extends State<WithdrawalActionBar> {
  /// A request is in flight: shows the spinner and disables the buttons.
  bool _busy = false;

  /// A confirmation or input dialog is open. Not shown anywhere (the dialog
  /// itself is the feedback); it only stops a second tap from opening a second
  /// dialog before the first appears.
  bool _asking = false;

  _Notice? _notice;

  AdminWithdrawal get _w => widget.withdrawal;

  /// Runs one action in two phases. [ask] shows the confirmation or input
  /// dialog and returns what to send, or null if the admin cancelled; nothing
  /// is busy or disabled while it is open. [send] then makes the call and
  /// returns the success message. The busy flag is set before anything awaits
  /// in each phase, so a second tap can never start a second action.
  Future<void> _run<T extends Object>({
    required Future<T?> Function() ask,
    required Future<String> Function(T input) send,
  }) async {
    if (_busy || _asking) return;

    _asking = true;
    final T? input;
    try {
      input = await ask();
    } finally {
      _asking = false;
    }
    if (input == null) return; // cancelled

    setState(() {
      _busy = true;
      _notice = null;
    });

    var changed = false;

    try {
      final success = await send(input);
      changed = true;
      if (mounted) setState(() => _notice = _Notice(success, isError: false));
    } on ApiException catch (error) {
      // A 400, 401 or 403 means the request itself was refused and nothing
      // happened. Anything else (a conflict, a record that vanished, a timeout
      // or a 500 after the server may have acted) leaves us unsure, so look
      // again.
      changed =
          !(error.statusCode == 400 ||
              error.isUnauthorized ||
              error.isForbidden);
      if (mounted) {
        setState(() => _notice = _Notice(error.message, isError: true));
      }
    } catch (_) {
      // An unreadable reply: the action may well have gone through.
      changed = true;
      if (mounted) {
        setState(
          () => _notice = const _Notice(
            'Something went wrong. Please try again.',
            isError: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (changed) await widget.onChanged();
  }

  Future<void> _approve() => _run<bool>(
    ask: () async {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Approve withdrawal',
        message:
            'Approve ${formatRupees(_w.netAmount)} for ${_w.userEmail}? If '
            'payouts are automatic it is sent to the payment provider now. '
            'Otherwise you pay it yourself, then use Mark paid.',
        confirmLabel: 'Approve',
      );
      return confirmed ? true : null;
    },
    send: (_) async {
      final decision = await widget.service.approve(_w.id);

      switch (decision.status) {
        case 'Completed':
          return 'Approved, and the payment provider has already paid it.';
        case 'Processing':
          return 'Approved and sent to the payment provider.';
        case 'Failed':
          return 'Approved, but the payment provider refused it. The money '
              'went back to the user.';
        default:
          return 'Approved. Pay it, then use Mark paid.';
      }
    },
  );

  Future<void> _decline() => _run<String>(
    ask: () => showWithdrawalInputDialog(
      context,
      title: 'Decline withdrawal',
      message:
          '${formatRupees(_w.amount)} goes back to the user\'s available '
          'balance, and they see your reason.',
      label: 'Reason (shown to the user)',
      confirmLabel: 'Decline',
      emptyError: 'Enter a reason.',
      multiline: true,
      danger: true,
    ),
    send: (reason) async {
      await widget.service.reject(_w.id, reason: reason);
      return 'Declined. The money went back to the user.';
    },
  );

  Future<void> _markPaid() => _run<String>(
    ask: () {
      final alsoApproves = _w.status == 'Requested'
          ? ' This also approves the request.'
          : '';

      return showWithdrawalInputDialog(
        context,
        title: 'Mark as paid',
        message:
            'Record that you paid ${formatRupees(_w.netAmount)} to '
            '${_w.destinationMasked}. This moves the money out of the '
            'user\'s wallet for good.$alsoApproves',
        label: 'Bank transaction reference',
        hint: 'UTR or transaction id',
        confirmLabel: 'Mark paid',
        emptyError: 'Enter the bank reference.',
        maxLength: 100,
      );
    },
    send: (reference) async {
      await widget.service.markPaid(_w.id, transactionReference: reference);
      return 'Recorded as paid.';
    },
  );

  Future<void> _markFailed() => _run<String>(
    ask: () => showWithdrawalInputDialog(
      context,
      title: 'Mark as failed',
      message:
          'Record that the payout could not be made. '
          '${formatRupees(_w.amount)} goes back to the user, and they see '
          'your reason.',
      label: 'Reason (shown to the user)',
      confirmLabel: 'Mark failed',
      emptyError: 'Enter a reason.',
      multiline: true,
      danger: true,
    ),
    send: (reason) async {
      await widget.service.markFailed(_w.id, reason: reason);
      return 'Recorded as failed. The money went back to the user.';
    },
  );

  Future<void> _acknowledge() => _run<bool>(
    ask: () async {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Mark as dealt with',
        message:
            'This clears the "needs attention" flag once you have checked '
            'it. No money moves.',
        confirmLabel: 'Acknowledge',
      );
      return confirmed ? true : null;
    },
    send: (_) async {
      await widget.service.acknowledge(_w.id);
      return 'Marked as dealt with.';
    },
  );

  @override
  Widget build(BuildContext context) {
    final actions = WithdrawalActions.of(_w);
    final notice = _notice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notice != null) ...[
          _NoticeBanner(notice: notice),
          const SizedBox(height: AdminSpacing.md),
        ],
        if (actions.providerOwns && !actions.any) ...[
          const Text(
            'The payment provider is handling this payout and it will update '
            'by itself. You can step in if it ends up needing attention.',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: AdminSpacing.md),
        ],
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AdminSpacing.sm,
          runSpacing: AdminSpacing.sm,
          children: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(right: AdminSpacing.sm),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (actions.decline)
              _textButton('Decline', _decline, AdminColors.danger),
            if (actions.markFailed)
              _textButton('Mark failed', _markFailed, AdminColors.danger),
            if (actions.acknowledge)
              _textButton('Acknowledge', _acknowledge, AdminColors.primary),
            widget.trailing,
            if (actions.markPaid)
              actions.approve
                  ? OutlinedButton(
                      onPressed: _busy ? null : _markPaid,
                      child: const Text('Mark paid'),
                    )
                  : FilledButton(
                      onPressed: _busy ? null : _markPaid,
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminColors.success,
                      ),
                      child: const Text('Mark paid'),
                    ),
            if (actions.approve)
              FilledButton(
                onPressed: _busy ? null : _approve,
                child: const Text('Approve'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _textButton(String label, VoidCallback onPressed, Color color) {
    return TextButton(
      onPressed: _busy ? null : onPressed,
      style: TextButton.styleFrom(foregroundColor: color),
      child: Text(label),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.notice});

  final _Notice notice;

  @override
  Widget build(BuildContext context) {
    final color = notice.isError ? AdminColors.danger : AdminColors.success;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AdminSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AdminRadius.input),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              notice.isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Text(
                notice.text,
                style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
