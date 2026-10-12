class RouteNames {
  RouteNames._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const dashboard = '/dashboard';
  static const profile = '/profile';
  static const profileSetup = '/profile-setup';

  // Browsing (categories / stores / offers). Search has no route of its own —
  // it runs inline on the dashboard.
  static const categories = '/categories';
  static const categoryStores = '/category-stores';
  static const stores = '/stores';
  static const storeDetails = '/store-details';
  static const offers = '/offers';
  static const offerDetails = '/offer-details';

  static const cashbackDetails = '/cashback-details';

  /// Pops with `true` when a withdrawal was requested, so the wallet reloads.
  static const withdraw = '/withdraw';

  /// The user's withdrawal history. Pops with `true` if one was cancelled.
  static const withdrawals = '/withdrawals';

  /// One withdrawal (argument: a `Withdrawal`). Pops with `true` if it was
  /// cancelled.
  static const withdrawalDetails = '/withdrawal-details';
}
