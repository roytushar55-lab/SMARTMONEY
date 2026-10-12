import 'package:flutter/material.dart';

/// ₹1,234.50, with thousands separators. For totals; single amounts in a row
/// use plain `₹494.10` (see the feature formatters).
String formatRupeesGrouped(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₹$whole.${parts[1]}';
}

const List<String> _months = [
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

/// "12 Oct" for one day, "9 Oct – 12 Oct" for a range.
String formatDateRangeLabel(DateTimeRange range) {
  String day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
  final sameDay = range.start == range.end;
  return sameDay ? day(range.start) : '${day(range.start)} – ${day(range.end)}';
}

/// "5 min ago", "3 h ago", "2 days ago". [now] defaults to the current time.
String formatAgo(DateTime then, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).toUtc().difference(then.toUtc());

  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';

  final days = difference.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}
