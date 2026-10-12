import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/auth/admin_session.dart';
import '../../core/auth/jwt_claims.dart';
import '../../core/theme/admin_colors.dart';
import '../affiliate/screens/affiliate_screen.dart';
import '../cashback_settings/screens/cashback_networks_screen.dart';
import '../cashbacks/screens/cashback_review_screen.dart';
import '../categories/screens/categories_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../offers/screens/offers_screen.dart';
import '../stores/screens/stores_screen.dart';
import '../users/screens/users_screen.dart';
import '../withdrawals/screens/withdrawals_screen.dart';
import '../withdrawals/withdrawal_attention_counter.dart';
import '../withdrawals/withdrawals_filter.dart';

enum _Section {
  dashboard,
  cashbacks,
  withdrawals,
  categories,
  stores,
  offers,
  cashbackSettings,
  affiliate,
  users,
}

/// Sidebar layout — the right pattern for web width, unlike the mobile app's
/// bottom nav. Menu items are filtered by role: SuperAdmin-only sections
/// (Users, Affiliate networks) never render for a plain Admin.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  _Section _section = _Section.dashboard;

  /// Set when the dashboard deep-links into the review queue with a filter.
  String? _pendingCashbackStatus;

  /// Set when the dashboard deep-links into the withdrawals list.
  WithdrawalsFilter? _pendingWithdrawalsFilter;

  /// Drives the badge on the Withdrawals item. Refreshed on every navigation
  /// and after any withdrawal action, so it is never older than the screen
  /// beside it; there is no timer.
  final _attentionCounter = WithdrawalAttentionCounter();

  @override
  void initState() {
    super.initState();
    _attentionCounter.refresh();
  }

  @override
  void dispose() {
    _attentionCounter.dispose();
    super.dispose();
  }

  void _goTo(
    _Section section, {
    String? cashbackStatus,
    WithdrawalsFilter? withdrawalsFilter,
  }) {
    setState(() {
      _section = section;
      _pendingCashbackStatus = cashbackStatus;
      _pendingWithdrawalsFilter = withdrawalsFilter;
    });
    _attentionCounter.refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when claims change (e.g. a refresh reveals a demotion), so
    // SuperAdmin-only items disappear without a reload. UI-only: the server
    // enforces roles on every request.
    return ValueListenableBuilder(
      valueListenable: AdminSession.instance.claims,
      builder: (context, claims, _) => _buildShell(claims),
    );
  }

  Widget _buildShell(JwtClaims? claims) {
    final isSuperAdmin = claims?.isSuperAdmin ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AdminBreakpoints.mobile;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AdminColors.bgPrimary,
            appBar: AppBar(
              backgroundColor: AdminColors.surface,
              foregroundColor: AdminColors.textPrimary,
              elevation: 0,
              toolbarHeight: 48,
            ),
            drawer: Drawer(
              width: 232,
              child: SafeArea(
                child: _buildSidebar(
                  isSuperAdmin,
                  claims?.email,
                  isDrawer: true,
                ),
              ),
            ),
            body: _buildContent(),
          );
        }

        return Scaffold(
          backgroundColor: AdminColors.bgPrimary,
          body: Row(
            children: [
              _buildSidebar(isSuperAdmin, claims?.email),
              Expanded(child: _buildContent()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    bool isSuperAdmin,
    String? email, {
    bool isDrawer = false,
  }) {
    return Container(
      width: isDrawer ? null : 232,
      color: AdminColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.lg,
              AdminSpacing.xl,
              AdminSpacing.lg,
              AdminSpacing.xl,
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/smartmoney_mark.png',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: AdminSpacing.sm),
                Image.asset(
                  'assets/images/smartmoney_wordmark.png',
                  height: 16,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          _navItem('Dashboard', Icons.dashboard_outlined, _Section.dashboard),
          _navItem(
            'Cashback review',
            Icons.receipt_long_outlined,
            _Section.cashbacks,
          ),
          _navItem(
            'Withdrawals',
            Icons.payments_outlined,
            _Section.withdrawals,
            badge: _attentionCounter,
          ),
          _navItem('Categories', Icons.category_outlined, _Section.categories),
          _navItem('Stores', Icons.storefront_outlined, _Section.stores),
          _navItem('Offers', Icons.local_offer_outlined, _Section.offers),
          _navItem(
            'Cashback settings',
            Icons.tune_outlined,
            _Section.cashbackSettings,
          ),
          if (isSuperAdmin) ...[
            _navItem(
              'Affiliate networks',
              Icons.hub_outlined,
              _Section.affiliate,
            ),
            _navItem('Users', Icons.people_outline, _Section.users),
          ],
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AdminColors.bgSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AdminColors.primary,
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    email ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => AdminSession.instance.logout(),
                  icon: const Icon(Icons.logout, size: 17),
                  color: AdminColors.textMuted,
                  tooltip: 'Sign out',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [badge], when given, shows its value as a small count at the end of the
  /// row whenever it is above zero.
  Widget _navItem(
    String label,
    IconData icon,
    _Section section, {
    ValueListenable<int?>? badge,
  }) {
    final selected = _section == section;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: 1,
      ),
      child: Material(
        color: selected
            ? AdminColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminRadius.input),
        child: InkWell(
          onTap: () {
            _goTo(section);
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(AdminRadius.input),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: selected ? AdminColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? AdminColors.primary
                      : AdminColors.textSecondary,
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AdminColors.primary
                          : AdminColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (badge != null)
                  ValueListenableBuilder<int?>(
                    valueListenable: badge,
                    builder: (context, count, _) => count == null || count <= 0
                        ? const SizedBox.shrink()
                        : _NavBadge(count: count),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isSuperAdmin =
        AdminSession.instance.claims.value?.isSuperAdmin ?? false;
    final section =
        !isSuperAdmin &&
            (_section == _Section.users || _section == _Section.affiliate)
        ? _Section.dashboard
        : _section;

    switch (section) {
      case _Section.dashboard:
        return DashboardScreen(
          onOpenReviewQueue: (status) =>
              _goTo(_Section.cashbacks, cashbackStatus: status),
          onOpenWithdrawals: (filter) =>
              _goTo(_Section.withdrawals, withdrawalsFilter: filter),
        );
      case _Section.cashbacks:
        return CashbackReviewScreen(
          key: ValueKey(_pendingCashbackStatus),
          initialStatus: _pendingCashbackStatus,
        );
      case _Section.withdrawals:
        return WithdrawalsScreen(
          key: ValueKey(_pendingWithdrawalsFilter),
          initialFilter:
              _pendingWithdrawalsFilter ?? WithdrawalsFilter.requested,
          onChanged: _attentionCounter.refresh,
        );
      case _Section.categories:
        return const CategoriesScreen();
      case _Section.stores:
        return const StoresScreen();
      case _Section.offers:
        return const OffersScreen();
      case _Section.cashbackSettings:
        return const CashbackNetworksScreen();
      case _Section.affiliate:
        return const AffiliateScreen();
      case _Section.users:
        return const UsersScreen();
    }
  }
}

/// The count pill on a sidebar item: how many withdrawals need attention.
class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AdminSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AdminColors.danger,
        borderRadius: BorderRadius.circular(AdminRadius.chip),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
