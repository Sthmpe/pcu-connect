/// One Sunday or Wednesday service in the month, for the Road to membership calendar.
class ServiceDay {
  final String day; // 'yyyy-MM-dd'
  final bool wednesday;
  final bool attended;
  final bool past;
  const ServiceDay({required this.day, required this.wednesday, required this.attended, required this.past});

  int get dayOfMonth => int.parse(day.substring(8));
}

/// Road to membership for one calendar month (Africa/Lagos): a guest becomes
/// a member with 4 Sundays, or 3 Sundays and 2 Wednesdays, in one month.
class MembershipProgress {
  static const sundaysAlone = 4;
  static const sundaysWithWednesdays = 3;
  static const wednesdays = 2;

  final String month; // 'yyyy-MM'
  final List<ServiceDay> sundays;
  final List<ServiceDay> wednesdaysInMonth;
  final int sundaysAttended;
  final int wednesdaysAttended;
  final String line;

  const MembershipProgress._({
    required this.month,
    required this.sundays,
    required this.wednesdaysInMonth,
    required this.sundaysAttended,
    required this.wednesdaysAttended,
    required this.line,
  });

  /// [today] is the Lagos day; [sundayDates] and [wednesdayDates] are the
  /// attended Lagos days (any month; only [today]'s month counts).
  factory MembershipProgress.of({
    required String today,
    required List<String> sundayDates,
    required List<String> wednesdayDates,
    required String status,
  }) {
    final month = today.substring(0, 7);
    final sun = sundayDates.where((d) => d.startsWith(month)).toSet();
    final wed = wednesdayDates.where((d) => d.startsWith(month)).toSet();
    final y = int.parse(month.substring(0, 4)), m = int.parse(month.substring(5, 7));
    final days = DateTime.utc(y, m + 1, 0).day;

    final sundays = <ServiceDay>[], weds = <ServiceDay>[];
    for (var d = 1; d <= days; d++) {
      final date = DateTime.utc(y, m, d);
      final key = '$month-${d.toString().padLeft(2, '0')}';
      if (date.weekday == DateTime.sunday) {
        sundays.add(ServiceDay(day: key, wednesday: false, attended: sun.contains(key), past: key.compareTo(today) < 0));
      } else if (date.weekday == DateTime.wednesday) {
        weds.add(ServiceDay(day: key, wednesday: true, attended: wed.contains(key), past: key.compareTo(today) < 0));
      }
    }
    // Services still ahead this month (today included) that were not attended yet.
    final sundaysLeft = sundays.where((s) => !s.past && !s.attended).length;
    final wednesdaysLeft = weds.where((s) => !s.past && !s.attended).length;

    return MembershipProgress._(
      month: month,
      sundays: sundays,
      wednesdaysInMonth: weds,
      sundaysAttended: sun.length,
      wednesdaysAttended: wed.length,
      line: lineFor(
        status: status,
        sundays: sun.length,
        wednesdays: wed.length,
        sundaysLeft: sundaysLeft,
        wednesdaysLeft: wednesdaysLeft,
        nextMonthFirst: DateTime.utc(y, m + 1, 1),
      ),
    );
  }

  static String _count(int n, String what) => '$n more $what${n == 1 ? '' : 's'}';

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// The line under the calendar, such as "1 more Sunday to become a member".
  static String lineFor({
    required String status,
    required int sundays,
    required int wednesdays,
    required int sundaysLeft,
    required int wednesdaysLeft,
    required DateTime nextMonthFirst,
  }) {
    if (status == 'Member') return 'Became a member. Thank you for walking with them.';
    if (sundays >= sundaysAlone || (sundays >= sundaysWithWednesdays && wednesdays >= MembershipProgress.wednesdays)) {
      return 'Has met the membership rule this month.';
    }

    // The two ways in: (Sundays needed, Wednesdays needed).
    final ways = <(int, int)>{
      (sundaysAlone - sundays, 0),
      ((sundaysWithWednesdays - sundays).clamp(0, 99), (MembershipProgress.wednesdays - wednesdays).clamp(0, 99)),
    }.where((w) => w.$1 <= sundaysLeft && w.$2 <= wednesdaysLeft).toList();

    if (ways.isEmpty) {
      return 'Not enough services left this month. The count starts again on 1 ${_months[nextMonthFirst.month - 1]}.';
    }
    final fewest = ways.map((w) => w.$1 + w.$2).reduce((a, b) => a < b ? a : b);
    final best = ways.where((w) => w.$1 + w.$2 == fewest).map((w) {
      final parts = [
        if (w.$1 > 0) _count(w.$1, 'Sunday'),
        if (w.$2 > 0) _count(w.$2, 'Wednesday'),
      ];
      return parts.join(' and ');
    }).toList();
    return '${best.join(', or ')} to become a member';
  }
}
