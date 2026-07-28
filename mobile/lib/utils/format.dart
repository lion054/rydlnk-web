import 'package:flutter/material.dart';

/// Formatting helpers shared between models, repositories and screens.

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// `DateTime` → Postgres `date` string, e.g. `2026-05-07`.
String dateToDb(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `TimeOfDay` → Postgres `time` string, e.g. `08:30:00`.
String timeToDb(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

/// Postgres `time` (`HH:mm:ss`) → friendly `8:30 AM`. Null-safe.
String? formatDbTime(String? hms) {
  if (hms == null || hms.isEmpty) return null;
  final parts = hms.split(':');
  if (parts.length < 2) return hms;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final period = h >= 12 ? 'PM' : 'AM';
  var hh = h % 12;
  if (hh == 0) hh = 12;
  return '$hh:$m $period';
}

/// `DateTime` → `May 17`.
String prettyDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// A relative label like `Today, May 17` / `Yesterday` / `May 13`.
String relativeDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = that.difference(today).inDays;
  if (diff == 0) return 'Today, ${prettyDate(d)}';
  if (diff == -1) return 'Yesterday';
  if (diff == 1) return 'Tomorrow';
  return prettyDate(d);
}

/// Weekday index (0=Sun … 6=Sat) → `Mon`.
String weekdayShort(int i) => _weekdayShort[i % 7];

/// Currency symbol — one place to localize. Zimbabwe transacts widely in USD;
/// change this (and the fare model in RoutingService) per launch market.
const String kCurrencySymbol = r'$';

/// Cents → `$8.17`.
String money(int? cents) {
  if (cents == null) return '—';
  return '$kCurrencySymbol${(cents / 100).toStringAsFixed(2)}';
}

/// Cents → rounded `$8` (used where space is tight).
String moneyRound(int? cents) {
  if (cents == null) return '—';
  return '$kCurrencySymbol${(cents / 100).round()}';
}
