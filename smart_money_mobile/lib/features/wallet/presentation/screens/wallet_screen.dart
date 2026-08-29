import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/view_state.dart';
import '../../data/models/wallet_summary.dart';
import '../../data/models/wallet_transaction.dart';
import '../../data/services/wallet_api_service.dart';
import '../wallet_transaction_copy.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Wallet tab: balance + ledger from `GET /api/wallet` and
/// `GET /api/wallet/transactions`.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletApiService _service = WalletApiService();

  ViewState _state = ViewState.initial;
  WalletSummary? _summary;
  List<WalletTransaction> _transactions = const [];
  String _error = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;

    setState(() => _state = ViewState.loading);

    try {
      final results = await Future.wait([
        _service.getMyWallet(),
        _service.getMyTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as WalletSummary;
        _transactions = results[1] as List<WalletTransaction>;
        _state = ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _state = ViewState.error;
      });
    } finally {
      _isLoading = false;
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature will be available soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(top: false, child: _buildBody(colors)),
    );
  }

  Widget _buildBody(SmColors colors) {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading your wallet...');
      case ViewState.error:
        return ErrorView(message: _error, onRetry: _load);
      case ViewState.empty:
      case ViewState.success:
        final summary = _summary;
        if (summary == null) {
          return const LoadingView();
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              SmSpacing.lg,
              SmSpacing.lg,
              SmSpacing.lg,
              SmSpacing.xxl,
            ),
            children: [
              _BalanceCard(summary: summary, colors: colors),
              const SizedBox(height: SmSpacing.lg),
              _ActionsRow(
                colors: colors,
                onWithdraw: () => _showComingSoon('Withdrawals'),
                onBankAccount: () => _showComingSoon('Bank account setup'),
              ),
              const SizedBox(height: SmSpacing.xl),
              _StatsRow(summary: summary, colors: colors),
              const SizedBox(height: SmSpacing.xl),
              Text(
                'Transactions',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SmSpacing.md),
              if (_transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: SmSpacing.xxl,
                  ),
                  child: Center(
                    child: Text(
                      'No transactions yet.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_transactions.length, (index) {
                  final transaction = _transactions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: SmSpacing.md),
                    child: _TransactionTile(
                      transaction: transaction,
                      colors: colors,
                    ),
                  );
                }),
            ],
          ),
        );
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.colors});

  final WalletSummary summary;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SmSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(SmRadius.cardLarge),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${summary.availableBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.colors,
    required this.onWithdraw,
    required this.onBankAccount,
  });

  final SmColors colors;
  final VoidCallback onWithdraw;
  final VoidCallback onBankAccount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            colors: colors,
            icon: Icons.account_balance_wallet_outlined,
            label: 'Withdraw',
            onTap: onWithdraw,
          ),
        ),
        const SizedBox(width: SmSpacing.md),
        Expanded(
          child: _ActionButton(
            colors: colors,
            icon: Icons.account_balance_outlined,
            label: 'Bank Account',
            onTap: onBankAccount,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final SmColors colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(SmRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(SmRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: SmSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SmRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: colors.primary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary, required this.colors});

  final WalletSummary summary;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, double value, Color valueColor) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: SmSpacing.md,
            horizontal: SmSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(SmRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Text(
                '₹${value.toStringAsFixed(0)}',
                style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('Pending', summary.pendingBalance, colors.warning),
        const SizedBox(width: SmSpacing.sm),
        stat('Total Earned', summary.totalEarned, colors.success),
        const SizedBox(width: SmSpacing.sm),
        stat('Withdrawn', summary.totalWithdrawn, colors.textSecondary),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.colors});

  final WalletTransaction transaction;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    final copy = WalletTransactionCopy.forType(transaction.type);

    return Container(
      padding: const EdgeInsets.all(SmSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SmRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (copy.isCredit ? colors.success : colors.danger)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              copy.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: copy.isCredit ? colors.success : colors.danger,
              size: 18,
            ),
          ),
          const SizedBox(width: SmSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.description ??
                      _formatDate(transaction.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${copy.isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: copy.isCredit ? colors.success : colors.danger,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
