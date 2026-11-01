/// Africa/Lagos time (UTC+1 all year, no daylight saving). Every day boundary
/// in the app uses it, whatever the device time zone.
abstract class LagosTime {
  static const Duration offset = Duration(hours: 1);

  /// Wall-clock time in Lagos, as a UTC DateTime holding Lagos values.
  static DateTime now([DateTime? clock]) =>
      (clock ?? DateTime.now()).toUtc().add(offset);

  /// 'yyyy-MM-dd' of [instant] in Lagos.
  static String day(DateTime instant) => _ymd(instant.toUtc().add(offset));

  static String today([DateTime? clock]) => _ymd(now(clock));

  /// 'yyyy-MM' of today in Lagos.
  static String month([DateTime? clock]) => today(clock).substring(0, 7);

  /// Whole calendar days from [fromDay] to [toDay] (both 'yyyy-MM-dd').
  static int daysBetween(String fromDay, String toDay) {
    final a = DateTime.tryParse(fromDay);
    final b = DateTime.tryParse(toDay);
    if (a == null || b == null) return 0;
    return DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
  }

  /// True when the Lagos day 'yyyy-MM-dd' is a Wednesday.
  static bool isWednesday(String day) {
    final d = DateTime.tryParse(day);
    return d != null && DateTime.utc(d.year, d.month, d.day).weekday == DateTime.wednesday;
  }

  /// 'yyyy-MM-dd' of a date picked on the device (its calendar day, not an instant).
  static String pickedDay(DateTime picked) => _ymd(picked);

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
