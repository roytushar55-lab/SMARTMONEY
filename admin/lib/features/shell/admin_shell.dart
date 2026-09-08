import 'package:flutter/material.dart';

import '../../core/auth/admin_session.dart';
import '../../core/theme/admin_colors.dart';
import '../affiliate/screens/affiliate_screen.dart';
import '../cashback_settings/screens/cashback_settings_screen.dart';
import '../cashbacks/screens/cashback_review_screen.dart';
import '../categories/screens/categories_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../offers/screens/offers_screen.dart';
import '../stores/screens/stores_screen.dart';
import '../users/screens/users_screen.dart';

enum _Section {
  dashboard,
  cashbacks,
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

  void _goTo(_Section section, {String? cashbackStatus}) {
    setState(() {
      _section = section;
      _pendingCashbackStatus = cashbackStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final claims = AdminSession.instance.claims.value;
    final isSuperAdmin = claims?.isSuperAdmin ?? false;

    return Scaffold(
      backgroundColor: AdminColors.bgPrimary,
      body: Row(
        children: [
          _buildSidebar(isSuperAdmin, claims?.email),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isSuperAdmin, String? email) {
    return Container(
      width: 220,
      color: AdminColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AdminSpacing.xl),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
            child: Text(
              'SmartMoney Admin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AdminColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AdminSpacing.xl),
          _navItem('Dashboard', Icons.dashboard_outlined, _Section.dashboard),
          _navItem('Cashback review', Icons.receipt_long_outlined, _Section.cashbacks),
          _navItem('Categories', Icons.category_outlined, _Section.categories),
          _navItem('Stores', Icons.storefront_outlined, _Section.stores),
          _navItem('Offers', Icons.local_offer_outlined, _Section.offers),
          _navItem(
            'Cashback settings',
            Icons.tune_outlined,
            _Section.cashbackSettings,
          ),
          if (isSuperAdmin) ...[
            _navItem('Affiliate networks', Icons.hub_outlined, _Section.affiliate),
            _navItem('Users', Icons.people_outline, _Section.users),
          ],
          const Spacer(),
          if (email != null)
            Padding(
              padding: const EdgeInsets.all(AdminSpacing.lg),
              child: Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.lg,
              0,
              AdminSpacing.lg,
              AdminSpacing.lg,
            ),
            child: OutlinedButton.icon(
              onPressed: () => AdminSession.instance.logout(),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String label, IconData icon, _Section section) {
    final selected = _section == section;

    return Material(
      color: selected ? AdminColors.bgSecondary : Colors.transparent,
      child: InkWell(
        onTap: () => _goTo(section),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg,
            vertical: AdminSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AdminColors.primary : AdminColors.textSecondary,
              ),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AdminColors.primary : AdminColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case _Section.dashboard:
        return DashboardScreen(
          onOpenReviewQueue: (status) =>
              _goTo(_Section.cashbacks, cashbackStatus: status),
        );
      case _Section.cashbacks:
        return CashbackReviewScreen(
          key: ValueKey(_pendingCashbackStatus),
          initialStatus: _pendingCashbackStatus,
        );
      case _Section.categories:
        return const CategoriesScreen();
      case _Section.stores:
        return const StoresScreen();
      case _Section.offers:
        return const OffersScreen();
      case _Section.cashbackSettings:
        return const CashbackSettingsScreen();
      case _Section.affiliate:
        return const AffiliateScreen();
      case _Section.users:
        return const UsersScreen();
    }
  }
}
