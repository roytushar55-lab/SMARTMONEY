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
import '../../data/models/cashback_item.dart';
import '../../data/services/cashback_api_service.dart';
import '../cashback_status_copy.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Cashback tracking tab: lists the signed-in user's cashback records from
/// `GET /api/cashbacks`, newest first.
class CashbackScreen extends StatefulWidget {
  const CashbackScreen({super.key, this.onExplore});

  /// Lets the empty state jump to the Explore tab.
  final VoidCallback? onExplore;

  @override
  State<CashbackScreen> createState() => _CashbackScreenState();
}

class _CashbackScreenState extends State<CashbackScreen> {
  final CashbackApiService _service = CashbackApiService();

  ViewState _state = ViewState.initial;
  List<CashbackItem> _items = const [];
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
      final items = await _service.getMyCashbacks();
      if (!mounted) return;
      setState(() {
        _items = items;
        _state = items.isEmpty ? ViewState.empty : ViewState.success;
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

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(title: const Text('Cashback')),
      body: SafeArea(top: false, child: _buildBody(colors)),
    );
  }

  Widget _buildBody(SmColors colors) {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading your cashback...');
      case ViewState.error:
        return ErrorView(
          message: _error,
          onRetry: _load,
          icon: Icons.cloud_off_rounded,
        );
      case ViewState.empty:
        return EmptyView(
          title: 'No cashback yet',
          message:
              'Start shopping and your rewards will appear here.',
          icon: Icons.savings_outlined,
          onRetry: widget.onExplore ?? _load,
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
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: SmSpacing.md),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _CashbackCard(
                item: item,
                colors: colors,
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.cashbackDetails,
                  arguments: item,
                ),
              );
            },
          ),
        );
    }
  }
}

class _CashbackCard extends StatelessWidget {
  const _CashbackCard({
    required this.item,
    required this.colors,
    required this.onTap,
  });

  final CashbackItem item;
  final SmColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPositive =
        item.status == CashbackStatus.confirmed ||
        item.status == CashbackStatus.paidOut;

    return InkWell(
      borderRadius: BorderRadius.circular(SmRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SmSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(SmRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.storeName ?? 'Store',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(
                  label: cashbackStatusLabel(item.status),
                  tone: cashbackStatusTone(item.status),
                ),
              ],
            ),
            const SizedBox(height: SmSpacing.sm),
            Text(
              '₹${item.cashbackAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isPositive ? colors.success : colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.confirmedDate != null
                  ? 'Confirmed on ${_formatDate(item.confirmedDate!)}'
                  : 'Expected by ${_formatDate(item.expectedConfirmationDate)}',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
