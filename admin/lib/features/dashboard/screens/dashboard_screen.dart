import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_stat_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/view_state.dart';
import '../../cashbacks/cashback_status_copy.dart';
import '../../cashbacks/services/admin_cashback_api_service.dart';
import '../../users/models/admin_user_stats.dart';
import '../../users/services/admin_user_api_service.dart';

/// Landing screen: a count per cashback status. There's no dedicated
/// summary endpoint — each card asks the existing list endpoint for
/// `pageSize=1` and reads `totalCount`, which is cheap and avoids a new
/// backend route just for this.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenReviewQueue});

  /// Lets a card jump straight to the review queue pre-filtered to its status.
  final void Function(String status) onOpenReviewQueue;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = AdminCashbackApiService();
  final _userService = AdminUserApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  final Map<String, int> _counts = {};
  AdminUserStats? _userStats;

  static const Map<String, IconData> _statusIcons = {
    'AwaitingAdminReview': Icons.hourglass_top_rounded,
    'Pending': Icons.schedule_rounded,
    'Confirmed': Icons.check_circle_outline_rounded,
    'Rejected': Icons.cancel_outlined,
    'Reversed': Icons.undo_rounded,
    'PaidOut': Icons.account_balance_wallet_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    _userService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);

    try {
      // Both requests fire immediately and run concurrently — only the
      // `await`s below are sequential, not the underlying HTTP calls.
      final pagesFuture = Future.wait(
        kCashbackStatusFilters.map(
          (status) => _service.list(status: status, page: 1, pageSize: 1),
        ),
      );
      final statsFuture = _userService.getStats();

      final pages = await pagesFuture;
      final userStats = await statsFuture;

      final counts = <String, int>{};
      for (var i = 0; i < kCashbackStatusFilters.length; i++) {
        counts[kCashbackStatusFilters[i]] = pages[i].totalCount;
      }

      setState(() {
        _counts
          ..clear()
          ..addAll(counts);
        _userStats = userStats;
        _state = ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Dashboard',
            description:
                'Cashback pipeline at a glance — tap a card to review.',
          ),
          const SizedBox(height: AdminSpacing.xxl),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading counts...');
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _load);
      case ViewState.empty:
      case ViewState.success:
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < AdminBreakpoints.mobile;
            final crossAxisCount = isMobile
                ? 2
                : constraints.maxWidth < 1000
                ? 3
                : 4;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Users'),
                  const SizedBox(height: AdminSpacing.sm),
                  _HeroStatCard(
                    icon: Icons.groups_rounded,
                    value: _userStats?.totalUsers ?? 0,
                    label: 'Total users',
                    color: AdminColors.primary,
                    trend: _userStats?.newThisWeek,
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactStat(
                          icon: Icons.check_circle_outline_rounded,
                          value: '${_userStats?.activeUsers ?? 0}',
                          label: 'Active',
                          color: AdminColors.success,
                        ),
                      ),
                      const SizedBox(width: AdminSpacing.md),
                      Expanded(
                        child: _CompactStat(
                          icon: Icons.person_off_rounded,
                          value: '${_userStats?.deactivatedUsers ?? 0}',
                          label: 'Deactivated',
                          color: AdminColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.xxl),
                  _buildSectionLabel('Cashback pipeline'),
                  const SizedBox(height: AdminSpacing.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: AdminSpacing.lg,
                      crossAxisSpacing: AdminSpacing.lg,
                      childAspectRatio: isMobile ? 1.05 : 1.4,
                    ),
                    itemCount: kCashbackStatusFilters.length,
                    itemBuilder: (context, index) {
                      final status = kCashbackStatusFilters[index];
                      return _buildCard(status, _counts[status] ?? 0);
                    },
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AdminColors.textMuted,
      ),
    );
  }

  Widget _buildCard(String status, int count) {
    final copy = CashbackStatusCopy.forStatus(status);

    return AdminStatCard(
      icon: _statusIcons[status] ?? Icons.circle_outlined,
      value: '$count',
      label: copy.label,
      color: copy.color,
      onTap: () => widget.onOpenReviewQueue(status),
    );
  }
}

/// Headline KPI: a big number with an optional trend badge. Sized by its
/// content (Column, not a fixed aspect ratio), so it never overflows
/// regardless of viewport width.
class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.trend,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  /// New count this week. Shown as a "+N this week" badge when non-null.
  final int? trend;

  @override
  Widget build(BuildContext context) {
    final valueColor = Color.lerp(color, Colors.black, 0.45)!;
    final labelColor = Color.lerp(color, Colors.black, 0.2)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AdminRadius.input),
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(width: AdminSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: labelColor, fontSize: 13),
              ),
            ],
          ),
          if (trend != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AdminColors.statusBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AdminRadius.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: Color.lerp(
                      AdminColors.statusBlue,
                      Colors.black,
                      0.35,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+$trend this week',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color.lerp(
                        AdminColors.statusBlue,
                        Colors.black,
                        0.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A slim, horizontally-laid-out stat — icon chip beside value/label. Its
/// height comes from content, not a fixed aspect ratio, so long labels wrap
/// or ellipsize instead of overflowing the box.
class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final valueColor = Color.lerp(color, Colors.black, 0.45)!;
    final labelColor = Color.lerp(color, Colors.black, 0.2)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.md,
        vertical: AdminSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminRadius.input),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: labelColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
