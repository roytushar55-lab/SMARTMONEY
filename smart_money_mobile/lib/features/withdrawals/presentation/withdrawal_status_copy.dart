import '../../../core/widgets/status_badge.dart';

/// Plain words for a raw backend `WithdrawalStatus`, per the app's rule of
/// never showing status names as the server spells them.
class WithdrawalStatusCopy {
  const WithdrawalStatusCopy({
    required this.label,
    required this.tone,
    required this.explanation,
  });

  /// Short, for a badge.
  final String label;
  final StatusTone tone;

  /// One or two sentences for the detail screen: what it means and whether
  /// the money is with us, on its way, or back in the wallet.
  final String explanation;

  factory WithdrawalStatusCopy.forStatus(String rawStatus) {
    switch (rawStatus) {
      case 'Requested':
        return const WithdrawalStatusCopy(
          label: 'Requested',
          tone: StatusTone.pending,
          explanation:
              "We're reviewing your request. You can cancel it until it is "
              'approved.',
        );
      case 'Approved':
        return const WithdrawalStatusCopy(
          label: 'Approved',
          tone: StatusTone.pending,
          explanation: 'Approved. The payment is being prepared.',
        );
      case 'Processing':
        return const WithdrawalStatusCopy(
          label: 'Processing',
          tone: StatusTone.pending,
          explanation: 'The payment is on its way to your account.',
        );
      case 'Completed':
        return const WithdrawalStatusCopy(
          label: 'Paid',
          tone: StatusTone.success,
          explanation: 'Paid to your account.',
        );
      case 'Failed':
        return const WithdrawalStatusCopy(
          label: 'Failed',
          tone: StatusTone.danger,
          explanation:
              'The payment could not be made. The money is back in your '
              'wallet.',
        );
      case 'Rejected':
        return const WithdrawalStatusCopy(
          label: 'Declined',
          tone: StatusTone.danger,
          explanation:
              'We could not approve this request. The money is back in your '
              'wallet.',
        );
      case 'Cancelled':
        return const WithdrawalStatusCopy(
          label: 'Cancelled',
          tone: StatusTone.neutral,
          explanation: 'You cancelled it. The money is back in your wallet.',
        );
      default:
        return const WithdrawalStatusCopy(
          label: 'In progress',
          tone: StatusTone.neutral,
          explanation: 'Your withdrawal is being handled.',
        );
    }
  }
}

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

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `11 Oct 2026` in the device's local time.
String formatWithdrawalDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
}

/// `11 Oct 2026, 18:05` in the device's local time.
String formatWithdrawalDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatWithdrawalDate(local)}, $hour:$minute';
}

String formatWithdrawalRupees(double value) => '₹${value.toStringAsFixed(2)}';
