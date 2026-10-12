import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/withdrawal.dart';
import '../../data/services/withdrawal_api_service.dart';
import '../withdrawal_status_copy.dart';

/// One withdrawal in full. It opens with the copy the list already had and
/// then asks the server for the latest, since a status can change at any
/// time. While it is still Requested the user may cancel it; the screen then
/// pops with `true` so the list and the wallet reload.
class WithdrawalDetailsScreen extends StatefulWidget {
  const WithdrawalDetailsScreen({
    super.key,
    required this.withdrawal,
    this.service,
  });

  final Withdrawal withdrawal;

  /// For tests. When null the screen creates, and later disposes, its own.
  final WithdrawalApiService? service;

  @override
  State<WithdrawalDetailsScreen> createState() =>
      _WithdrawalDetailsScreenState();
}

class _WithdrawalDetailsScreenState extends State<WithdrawalDetailsScreen> {
  late final WithdrawalApiService _service =
      widget.service ?? WithdrawalApiService();

  late Withdrawal _withdrawal = widget.withdrawal;
  bool _refreshing = false;
  bool _cancelling = false;
  String? _error;

  /// Set once a cancel succeeded.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final fresh = await _service.get(_withdrawal.id);
      if (!mounted) return;
      setState(() {
        _withdrawal = fresh;
        _refreshing = false;
      });
    } catch (_) {
      // The copy we came in with is still worth showing.
      if (!mounted) return;
      setState(() => _refreshing = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this withdrawal?'),
        content: Text(
          '${formatWithdrawalRupees(_withdrawal.amount)} will go back to '
          'your wallet straight away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel withdrawal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
      _error = null;
    });

    try {
      await _service.cancel(_withdrawal.id);
      if (!mounted) return;
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Withdrawal cancelled. '
            '${formatWithdrawalRupees(_withdrawal.amount)} is back in your '
            'wallet.',
          ),
        ),
      );
      setState(() => _cancelling = false);
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = e.message;
      });
      // Too late to cancel, or already gone: show what it has become.
      if (e.statusCode == 409 || e.statusCode == 404) _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = 'Unable to cancel right now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final withdrawal = _withdrawal;
    final copy = WithdrawalStatusCopy.forStatus(withdrawal.status);

    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: colors.bgPrimary,
        appBar: AppBar(
          title: const Text('Withdrawal'),
          actions: [
            if (_refreshing)
              const Padding(
                padding: EdgeInsets.all(SmSpacing.lg),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SmSpacing.lg,
              SmSpacing.lg,
              SmSpacing.lg,
              SmSpacing.xxl,
            ),
            children: [
              _buildHeader(colors, withdrawal, copy),
              const SizedBox(height: SmSpacing.lg),
              _card(colors, [
                _row(
                  colors,
                  'Amount',
                  formatWithdrawalRupees(withdrawal.amount),
                ),
                if (withdrawal.userFee > 0)
                  _row(
                    colors,
                    'Fee (your share)',
                    '- ${formatWithdrawalRupees(withdrawal.userFee)}',
                  ),
                _row(
                  colors,
                  withdrawal.status == 'Completed' ? 'Paid' : "You'll receive",
                  formatWithdrawalRupees(withdrawal.netAmount),
                  strong: true,
                ),
              ]),
              const SizedBox(height: SmSpacing.md),
              _card(colors, [
                _row(colors, 'Pay to', withdrawal.destination),
                _row(
                  colors,
                  'Method',
                  withdrawalMethodLabel(withdrawal.method),
                ),
                _row(colors, 'Reference', withdrawal.reference),
                _row(
                  colors,
                  'Requested',
                  formatWithdrawalDateTime(withdrawal.requestedAt),
                ),
                if (withdrawal.settledAt != null)
                  _row(
                    colors,
                    withdrawal.status == 'Completed' ? 'Paid on' : 'Closed',
                    formatWithdrawalDateTime(withdrawal.settledAt!),
                  ),
                if (withdrawal.transactionReference != null)
                  _row(
                    colors,
                    'Bank reference',
                    withdrawal.transactionReference!,
                  ),
              ]),
              if (withdrawal.failureReason != null &&
                  withdrawal.failureReason!.trim().isNotEmpty) ...[
                const SizedBox(height: SmSpacing.md),
                _card(colors, [
                  Text(
                    'Reason',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SmSpacing.xs),
                  Text(
                    withdrawal.failureReason!,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ]),
              ],
              if (withdrawal.canCancel) ...[
                const SizedBox(height: SmSpacing.xl),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: SmSpacing.sm),
                ],
                OutlinedButton(
                  onPressed: _cancelling ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.danger,
                    side: BorderSide(
                      color: colors.danger.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SmRadius.button),
                    ),
                  ),
                  child: _cancelling
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.danger,
                          ),
                        )
                      : const Text(
                          'Cancel withdrawal',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    SmColors colors,
    Withdrawal withdrawal,
    WithdrawalStatusCopy copy,
  ) {
    return Container(
      padding: const EdgeInsets.all(SmSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SmRadius.cardLarge),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(label: copy.label, tone: copy.tone),
          const SizedBox(height: SmSpacing.md),
          Text(
            formatWithdrawalRupees(withdrawal.amount),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: SmSpacing.sm),
          Text(
            copy.explanation,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(SmColors colors, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(SmSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SmRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _row(
    SmColors colors,
    String label,
    String value, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: SmSpacing.md),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: strong ? colors.success : colors.textPrimary,
                fontSize: strong ? 15 : 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
