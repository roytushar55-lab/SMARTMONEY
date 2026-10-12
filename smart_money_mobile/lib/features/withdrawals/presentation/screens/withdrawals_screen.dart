import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/view_state.dart';
import '../../data/models/withdrawal.dart';
import '../../data/services/withdrawal_api_service.dart';
import '../withdrawal_status_copy.dart';

/// The user's withdrawals, newest first, from `GET /api/withdrawals`. A row
/// opens the withdrawal; the screen pops with `true` if one was cancelled
/// while it was open, so the wallet behind it reloads.
class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({super.key, this.service});

  /// For tests. When null the screen creates, and later disposes, its own.
  final WithdrawalApiService? service;

  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen> {
  late final WithdrawalApiService _service =
      widget.service ?? WithdrawalApiService();

  ViewState _state = ViewState.initial;
  List<Withdrawal> _items = const [];
  String _error = '';
  bool _hasMore = false;
  bool _loadingMore = false;
  int _page = 1;

  /// A withdrawal was cancelled from the detail screen.
  bool _changed = false;

  /// Monotonic token so a slow earlier response can't overwrite a later one.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() => _state = ViewState.loading);

    try {
      final page = await _service.list(page: 1);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _items = page.items;
        _page = 1;
        _hasMore = page.hasNextPage;
        _state = page.items.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _state = ViewState.error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final token = _loadToken;
    setState(() => _loadingMore = true);

    try {
      final page = await _service.list(page: _page + 1);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _items = [..._items, ...page.items];
        _page = page.page;
        _hasMore = page.hasNextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more. Please try again.')),
      );
    }
  }

  Future<void> _open(Withdrawal withdrawal) async {
    final changed = await Navigator.pushNamed(
      context,
      RouteNames.withdrawalDetails,
      arguments: withdrawal,
    );
    if (changed == true && mounted) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    // Whatever way the user leaves, the wallet learns about a cancellation.
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: colors.bgPrimary,
        appBar: AppBar(title: const Text('Withdrawals')),
        body: SafeArea(top: false, child: _buildBody(colors)),
      ),
    );
  }

  Widget _buildBody(SmColors colors) {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading your withdrawals...');
      case ViewState.error:
        return ErrorView(
          message: _error,
          onRetry: _load,
          icon: Icons.cloud_off_rounded,
        );
      case ViewState.empty:
        return const EmptyView(
          title: 'No withdrawals yet',
          message: 'Withdraw from your wallet and it will show up here.',
          icon: Icons.payments_outlined,
        );
      case ViewState.success:
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              SmSpacing.lg,
              SmSpacing.lg,
              SmSpacing.lg,
              SmSpacing.xxl,
            ),
            itemCount: _items.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: SmSpacing.md),
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return Center(
                  child: _loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(SmSpacing.md),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          onPressed: _loadMore,
                          child: const Text('Load more'),
                        ),
                );
              }
              final withdrawal = _items[index];
              return _WithdrawalCard(
                withdrawal: withdrawal,
                colors: colors,
                onTap: () => _open(withdrawal),
              );
            },
          ),
        );
    }
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({
    required this.withdrawal,
    required this.colors,
    required this.onTap,
  });

  final Withdrawal withdrawal;
  final SmColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = WithdrawalStatusCopy.forStatus(withdrawal.status);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(SmRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(SmRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(SmSpacing.md),
          decoration: BoxDecoration(
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
                  color: colors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  withdrawal.method == 'Upi'
                      ? Icons.qr_code_2_rounded
                      : Icons.account_balance_outlined,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: SmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatWithdrawalRupees(withdrawal.amount),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${withdrawal.destination} · '
                      '${formatWithdrawalDate(withdrawal.requestedAt)}',
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
              const SizedBox(width: SmSpacing.sm),
              StatusBadge(label: copy.label, tone: copy.tone),
              const SizedBox(width: SmSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
