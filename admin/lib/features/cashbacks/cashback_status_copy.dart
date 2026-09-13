import 'package:flutter/material.dart';

import '../../core/theme/admin_colors.dart';

/// Friendly label + color for a raw `CashbackStatus` value from the backend.
class CashbackStatusCopy {
  const CashbackStatusCopy({required this.label, required this.color});

  final String label;
  final Color color;

  factory CashbackStatusCopy.forStatus(String rawStatus) {
    switch (rawStatus) {
      case 'Pending':
        return const CashbackStatusCopy(
          label: 'Pending',
          color: AdminColors.textMuted,
        );
      case 'AwaitingAdminReview':
        return const CashbackStatusCopy(
          label: 'Awaiting review',
          color: AdminColors.warning,
        );
      case 'Confirmed':
        return const CashbackStatusCopy(
          label: 'Confirmed',
          color: AdminColors.success,
        );
      case 'Rejected':
        return const CashbackStatusCopy(
          label: 'Rejected',
          color: AdminColors.danger,
        );
      case 'Reversed':
        return const CashbackStatusCopy(
          label: 'Reversed',
          color: AdminColors.danger,
        );
      case 'PaidOut':
        return const CashbackStatusCopy(
          label: 'Paid out',
          color: AdminColors.primary,
        );
      default:
        return const CashbackStatusCopy(
          label: 'Unknown',
          color: AdminColors.textMuted,
        );
    }
  }
}

const List<String> kCashbackStatusFilters = [
  'AwaitingAdminReview',
  'Pending',
  'Confirmed',
  'Rejected',
  'Reversed',
  'PaidOut',
];
