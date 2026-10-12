/// Rupees with two decimals, for example `₹494.10`.
String formatRupees(double value) => '₹${value.toStringAsFixed(2)}';

/// Local time as `2026-10-11 18:05`, so a timestamp matches the admin's clock.
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
