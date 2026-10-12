import 'package:flutter/material.dart';

import '../../core/theme/admin_colors.dart';

/// Friendly label + color for a raw `WithdrawalStatus` value from the backend.
class WithdrawalStatusCopy {
  const WithdrawalStatusCopy({required this.label, required this.color});

  final String label;
  final Color color;

  factory WithdrawalStatusCopy.forStatus(String rawStatus) {
    switch (rawStatus) {
      case 'Requested':
        return const WithdrawalStatusCopy(
          label: 'Requested',
          color: AdminColors.warning,
        );
      case 'Approved':
        return const WithdrawalStatusCopy(
          label: 'Approved',
          color: AdminColors.statusBlue,
        );
      case 'Processing':
        return const WithdrawalStatusCopy(
          label: 'Processing',
          color: AdminColors.primary,
        );
      case 'Completed':
        return const WithdrawalStatusCopy(
          label: 'Paid',
          color: AdminColors.success,
        );
      case 'Failed':
        return const WithdrawalStatusCopy(
          label: 'Failed',
          color: AdminColors.danger,
        );
      case 'Rejected':
        return const WithdrawalStatusCopy(
          label: 'Declined',
          color: AdminColors.statusPink,
        );
      case 'Cancelled':
        return const WithdrawalStatusCopy(
          label: 'Cancelled',
          color: AdminColors.textMuted,
        );
      default:
        return const WithdrawalStatusCopy(
          label: 'Unknown',
          color: AdminColors.textMuted,
        );
    }
  }
}

/// Raw statuses in the order the filter chips show them: the ones an admin
/// acts on first.
const List<String> kWithdrawalStatusFilters = [
  'Requested',
  'Approved',
  'Processing',
  'Completed',
  'Failed',
  'Rejected',
  'Cancelled',
];

/// Friendly label for a raw `PayoutMethod` value (`Upi`, `BankTransfer`).
String withdrawalMethodLabel(String rawMethod) {
  switch (rawMethod) {
    case 'Upi':
      return 'UPI';
    case 'BankTransfer':
      return 'Bank transfer';
    default:
      return rawMethod.isEmpty ? '—' : rawMethod;
  }
}
