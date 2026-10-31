import 'package:intl/intl.dart';

/// Months travel as API keys ('2026-10') and are only formatted for display.
abstract class MonthUtils {
  static final _key = DateFormat('yyyy-MM');

  static String keyOf(DateTime date) => _key.format(date);

  static String current() => keyOf(DateTime.now());

  /// The last [count] month keys, newest first.
  static List<String> recent([int count = 6]) {
    final now = DateTime.now();
    return [
      for (var i = 0; i < count; i++) keyOf(DateTime(now.year, now.month - i)),
    ];
  }

  static DateTime? _parse(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    return DateTime(y, m);
  }

  /// '2026-10' -> 'October 2026'
  static String label(String key) {
    final d = _parse(key);
    return d == null ? key : DateFormat('MMMM y').format(d);
  }

  /// '2026-10' -> 'Oct 2026'
  static String short(String key) {
    final d = _parse(key);
    return d == null ? key : DateFormat('MMM y').format(d);
  }

  /// '2026-10' -> 'October'
  static String name(String key) {
    final d = _parse(key);
    return d == null ? key : DateFormat('MMMM').format(d);
  }
}
