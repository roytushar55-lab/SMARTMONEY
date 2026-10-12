import 'package:flutter_test/flutter_test.dart';
import 'package:smartmoney_admin/features/withdrawals/withdrawal_formatters.dart';

void main() {
  group('formatRupees', () {
    test('always shows two decimals', () {
      expect(formatRupees(494.1), '₹494.10');
      expect(formatRupees(500), '₹500.00');
      expect(formatRupees(0), '₹0.00');
    });

    test('rounds to the paisa', () {
      expect(formatRupees(1234.567), '₹1234.57');
      expect(formatRupees(0.004), '₹0.00');
    });
  });

  group('formatDateTime', () {
    test('pads to YYYY-MM-DD HH:mm', () {
      expect(formatDateTime(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
      expect(formatDateTime(DateTime(2026, 10, 11, 18, 5)), '2026-10-11 18:05');
    });

    test('drops seconds', () {
      expect(
        formatDateTime(DateTime(2026, 10, 11, 9, 30, 59)),
        '2026-10-11 09:30',
      );
    });

    test('shows a UTC instant in the local zone', () {
      final utc = DateTime.utc(2026, 10, 11, 23, 30);
      final local = utc.toLocal();

      expect(formatDateTime(utc), formatDateTime(local));
      expect(
        formatDateTime(utc),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')),
      );
    });
  });
}
