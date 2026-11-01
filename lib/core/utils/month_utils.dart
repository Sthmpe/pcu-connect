import 'package:intl/intl.dart';
import 'lagos_time.dart';

/// Months travel as API keys ('2026-10') and are only formatted for display.
abstract class MonthUtils {
  static final _key = DateFormat('yyyy-MM');

  static String keyOf(DateTime date) => _key.format(date);

  /// This month in Africa/Lagos, whatever the device's time zone (the
  /// backend counts months the same way).
  static String current([DateTime? clock]) => LagosTime.month(clock);

  /// The last [count] month keys, newest first (Lagos time).
  static List<String> recent([int count = 6, DateTime? clock]) {
    final now = LagosTime.now(clock);
    return [
      for (var i = 0; i < count; i++) keyOf(DateTime(now.year, now.month - i)),
    ];
  }

  /// The month before [key]: '2026-01' -> '2025-12'.
  static String previous(String key) {
    final d = _parse(key);
    return d == null ? key : keyOf(DateTime(d.year, d.month - 1));
  }

  static bool isCurrent(String key) => key == current();

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

  /// Chip label: 'This month' for the current month, else 'Sep', or 'Dec 2025'
  /// when the year differs from now.
  static String chip(String key) {
    if (isCurrent(key)) return 'This month';
    final d = _parse(key);
    if (d == null) return key;
    return d.year == LagosTime.now().year
        ? DateFormat('MMM').format(d)
        : DateFormat('MMM y').format(d);
  }

  /// '2026-10' -> 'October'
  static String name(String key) {
    final d = _parse(key);
    return d == null ? key : DateFormat('MMMM').format(d);
  }
}
