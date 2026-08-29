import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/sm_bottom_nav_bar.dart';
import '../../../browsing/presentation/screens/explore_screen.dart';
import '../../../cashback/presentation/screens/cashback_screen.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../profile/presentation/screens/profile_setup_screen.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';

/// Tabs hosted by [MainShell]. The order matches [MainShellState] children
/// and the bottom nav bar.
enum ShellTab { home, explore, cashback, wallet, profile }

const _navItems = [
  SmBottomNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  SmBottomNavItem(
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore_rounded,
    label: 'Explore',
  ),
  SmBottomNavItem(
    icon: Icons.savings_outlined,
    activeIcon: Icons.savings_rounded,
    label: 'Cashback',
  ),
  SmBottomNavItem(
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet_rounded,
    label: 'Wallet',
  ),
  SmBottomNavItem(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

/// How long a first back-press "counts" before requiring a fresh confirm.
const _exitConfirmWindow = Duration(seconds: 2);

/// Shell around the app's main sections, navigated with a bottom nav bar.
///
/// Tabs are held alive in an [IndexedStack] so scroll position and already
/// loaded data survive tab switches (and the API isn't re-hit on every
/// switch). Tabs are built lazily — a tab's screen is only constructed the
/// first time it is visited.
///
/// This is also the app's authenticated root, so back-navigation is handled
/// by hand rather than left to the platform default: on web in particular,
/// `pushReplacementNamed` from Login doesn't reliably stop the browser's own
/// back button from resurfacing the replaced route, which would otherwise
/// let a signed-in user "back" into the login screen. Intercepting the pop
/// here means back always either returns to the Home tab or requires a
/// second confirming press to exit, and never falls through to whatever the
/// platform/browser thinks came before.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = ShellTab.home});

  /// Identifies the single shell instance so other screens (e.g. a pushed
  /// route reached from a "see all" header) can switch tabs from anywhere —
  /// including routes that sit above the shell on the navigator, so no
  /// ancestor lookup could reach it.
  static final GlobalKey<MainShellState> shellKey =
      GlobalKey<MainShellState>();

  final ShellTab initialTab;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex = widget.initialTab.index;
  late final Set<int> _visited = {widget.initialTab.index};

  DateTime? _lastBackPressAt;

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  /// Lets other screens switch tabs.
  void goToTab(ShellTab tab) => _selectTab(tab.index);

  void _handleBackPress() {
    if (_currentIndex != ShellTab.home.index) {
      goToTab(ShellTab.home);
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPressAt;
    if (last != null && now.difference(last) < _exitConfirmWindow) {
      // Confirmed: exits on Android, harmlessly ignored elsewhere (web has
      // no equivalent — there is nothing further back to fall into).
      SystemNavigator.pop();
      return;
    }

    _lastBackPressAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: _exitConfirmWindow,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _lazyTab(0, () => DashboardScreen(onSelectTab: goToTab)),
            _lazyTab(1, () => const ExploreScreen()),
            _lazyTab(
              2,
              () => CashbackScreen(
                onExplore: () => goToTab(ShellTab.explore),
              ),
            ),
            _lazyTab(3, () => const WalletScreen()),
            _lazyTab(4, () => const ProfileSetupScreen()),
          ],
        ),
        bottomNavigationBar: SmBottomNavBar(
          items: _navItems,
          currentIndex: _currentIndex,
          onTap: _selectTab,
        ),
      ),
    );
  }

  Widget _lazyTab(int index, Widget Function() builder) {
    if (!_visited.contains(index)) {
      return const SizedBox.shrink();
    }
    return builder();
  }
}
