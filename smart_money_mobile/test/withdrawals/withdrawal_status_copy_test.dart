import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/core/widgets/status_badge.dart';
import 'package:smart_money_mobile/features/withdrawals/presentation/withdrawal_status_copy.dart';

void main() {
  WithdrawalStatusCopy copy(String status) =>
      WithdrawalStatusCopy.forStatus(status);

  test('open statuses read as pending', () {
    expect(copy('Requested').label, 'Requested');
    expect(copy('Requested').tone, StatusTone.pending);
    expect(copy('Requested').explanation, contains('cancel'));
    expect(copy('Approved').tone, StatusTone.pending);
    expect(copy('Processing').tone, StatusTone.pending);
  });

  test('a paid withdrawal is a success', () {
    expect(copy('Completed').label, 'Paid');
    expect(copy('Completed').tone, StatusTone.success);
  });

  test('failed and declined say the money came back', () {
    expect(copy('Failed').tone, StatusTone.danger);
    expect(copy('Failed').explanation, contains('back in your wallet'));
    expect(copy('Rejected').label, 'Declined');
    expect(copy('Rejected').tone, StatusTone.danger);
    expect(copy('Rejected').explanation, contains('back in your wallet'));
    expect(copy('Cancelled').tone, StatusTone.neutral);
    expect(copy('Cancelled').explanation, contains('back in your wallet'));
  });

  test('an unknown status never shows its raw name', () {
    expect(copy('SomethingNew').label, 'In progress');
    expect(copy('SomethingNew').tone, StatusTone.neutral);
  });

  test('method labels', () {
    expect(withdrawalMethodLabel('Upi'), 'UPI');
    expect(withdrawalMethodLabel('BankTransfer'), 'Bank transfer');
    expect(withdrawalMethodLabel(''), '—');
  });

  test('dates are shown in local time', () {
    final utc = DateTime.utc(2026, 10, 11, 12, 30);
    final local = utc.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    expect(
      formatWithdrawalDate(utc),
      '${local.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][local.month - 1]} ${local.year}',
    );
    expect(formatWithdrawalDateTime(utc), endsWith(', $hour:$minute'));
    expect(formatWithdrawalRupees(494.1), '₹494.10');
  });
}
