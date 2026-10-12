import 'package:flutter/foundation.dart';

import 'services/admin_withdrawal_api_service.dart';

/// How many withdrawals currently need an admin's attention, for the sidebar
/// badge. The value is null until the first successful load. A failed refresh
/// keeps the last known number rather than making the badge flicker away;
/// the list screen is where errors are shown.
class WithdrawalAttentionCounter extends ValueNotifier<int?> {
  WithdrawalAttentionCounter({AdminWithdrawalApiService? service})
    : _service = service ?? AdminWithdrawalApiService(),
      _ownsService = service == null,
      super(null);

  final AdminWithdrawalApiService _service;
  final bool _ownsService;

  /// Monotonic token so a slow earlier response can't overwrite a later one.
  int _token = 0;
  bool _disposed = false;

  /// Asks the list endpoint for the count only (one row, `totalCount`).
  Future<void> refresh() async {
    final token = ++_token;
    try {
      final page = await _service.list(needsAttentionOnly: true, pageSize: 1);
      if (_disposed || token != _token) return;
      value = page.totalCount;
    } catch (_) {
      // Keep the last known count; a badge is not the place for an error.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsService) _service.dispose();
    super.dispose();
  }
}
