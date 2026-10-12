import 'package:flutter/material.dart';

import '../../core/theme/admin_colors.dart';
import 'cashback_status_copy.dart';
import 'models/admin_cashback.dart';

/// How one line of a cashback's audit trail reads.
class CashbackEventCopy {
  const CashbackEventCopy({required this.label, required this.color});

  /// What happened, for example "Approved".
  final String label;
  final Color color;

  factory CashbackEventCopy.forType(String type) {
    switch (type) {
      case 'Created':
        return const CashbackEventCopy(
          label: 'Created from the network report',
          color: AdminColors.statusBlue,
        );
      case 'NetworkStatusChanged':
        return const CashbackEventCopy(
          label: 'Network changed its status',
          color: AdminColors.textMuted,
        );
      case 'FlaggedForReview':
        return const CashbackEventCopy(
          label: 'Sent for review',
          color: AdminColors.warning,
        );
      case 'Approved':
        return const CashbackEventCopy(
          label: 'Approved',
          color: AdminColors.success,
        );
      case 'ApprovedByOverride':
        return const CashbackEventCopy(
          label: 'Approved anyway (override)',
          color: AdminColors.warning,
        );
      case 'Rejected':
        return const CashbackEventCopy(
          label: 'Rejected',
          color: AdminColors.danger,
        );
      case 'Reversed':
        return const CashbackEventCopy(
          label: 'Reversed',
          color: AdminColors.statusPink,
        );
      default:
        return CashbackEventCopy(
          label: type.isEmpty ? 'Unknown event' : type,
          color: AdminColors.textMuted,
        );
    }
  }
}

/// "by Asha Admin (asha@example.com)", or "by the network" for the
/// automatic ones.
String cashbackEventActor(AdminCashbackEvent event) {
  final name = (event.actorName ?? '').trim();
  final email = (event.actorEmail ?? '').trim();

  if (name.isNotEmpty && email.isNotEmpty) return 'by $name ($email)';
  if (name.isNotEmpty) return 'by $name';
  if (email.isNotEmpty) return 'by $email';
  return 'by the network';
}

/// "Pending to Awaiting review" when the status moved, otherwise null.
String? cashbackEventStatusChange(AdminCashbackEvent event) {
  final from = event.fromStatus;
  if (from == null || from == event.toStatus) return null;

  return '${CashbackStatusCopy.forStatus(from).label} to '
      '${CashbackStatusCopy.forStatus(event.toStatus).label}';
}
