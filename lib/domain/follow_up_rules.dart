import '../core/utils/lagos_time.dart';

/// What the app knows about a guest's work fields before a follow-up
/// (the guest document in Firestore).
class GuestWorkState {
  final String serviceDate; // 'yyyy-MM-dd' in Lagos, '' when unknown
  final String status;
  final int followUpCount;

  /// True once any follow-up was saved (firstCallAt is set).
  final bool hasFollowUps;
  final String teamJoined;
  final List<String> sundayDates;
  final List<String> wednesdayDates;
  final bool hasMemberSince;

  const GuestWorkState({
    required this.serviceDate,
    required this.status,
    required this.followUpCount,
    required this.hasFollowUps,
    required this.teamJoined,
    required this.sundayDates,
    required this.wednesdayDates,
    required this.hasMemberSince,
  });
}

/// One follow-up as entered on the log screen. Dates are Lagos days.
class FollowUpInput {
  final String outcome;
  final String note;
  final bool attendedSunday;
  final String sundayDate;
  final bool attendedWednesday;
  final String wednesdayDate;
  final String team;

  const FollowUpInput({
    required this.outcome,
    required this.note,
    this.attendedSunday = false,
    this.sundayDate = '',
    this.attendedWednesday = false,
    this.wednesdayDate = '',
    this.team = '',
  });
}

/// The result of applying a follow-up: its points and the guest's new work fields.
class FollowUpResult {
  final int points;
  final String status;
  final int followUpCount;
  final bool isFirstCall;
  final bool becameMember;
  final String teamJoined;
  final List<String> sundayDates;
  final List<String> wednesdayDates;

  const FollowUpResult({
    required this.points,
    required this.status,
    required this.followUpCount,
    required this.isFirstCall,
    required this.becameMember,
    required this.teamJoined,
    required this.sundayDates,
    required this.wednesdayDates,
  });
}

/// The PCU business rules for one follow-up (docs/BACKEND_PLAN.md), applied
/// on the device when the app saves. They match pcuLogFollowUp_ and
/// pcuNextStatus_ in backend/Api.gs.
abstract class FollowUpRules {
  static const outcomes = ['Reached', 'No answer', 'Busy', 'Switched off', 'Wrong number', 'Not interested'];
  static const teams = ['', 'Workforce', 'Evangelism'];

  static const firstCallPoints = 10;
  static const followUpPoints = 5;
  static const attendancePoints = 10;
  static const teamJoinPoints = 20;
  static const memberPoints = 30;

  static const firstCallWindowDays = 3;
  static const unreachableAfter = 3;
  static const maxNoteLength = 2000;

  static const member = 'Member';
  static const notInterested = 'Not interested';
  static const returning = 'Returning';
  static const contacted = 'Contacted';
  static const unreachable = 'Unreachable';
  static const newGuest = 'New guest';

  /// A plain message when the follow-up cannot be saved, otherwise null.
  static String? validate(FollowUpInput f, {required String today}) {
    if (!outcomes.contains(f.outcome)) return 'Choose how the call went.';
    if (!teams.contains(f.team)) return 'Choose a team from the list.';
    if (f.note.length > maxNoteLength) return 'The note is too long. Keep it under 2,000 characters.';
    for (final (on, day) in [(f.attendedSunday, f.sundayDate), (f.attendedWednesday, f.wednesdayDate)]) {
      if (!on) continue;
      if (day.isEmpty) return 'Pick the date they attended.';
      if (day.compareTo(today) > 0) return 'Attendance date cannot be in the future.';
    }
    return null;
  }

  /// Member = 4 distinct Sundays, or 3 Sundays and 2 Wednesdays, in one calendar month.
  static bool qualifies(Iterable<String> sundays, Iterable<String> wednesdays) {
    final months = <String, List<int>>{};
    for (final d in sundays.toSet()) {
      (months[d.substring(0, 7)] ??= [0, 0])[0]++;
    }
    for (final d in wednesdays.toSet()) {
      (months[d.substring(0, 7)] ??= [0, 0])[1]++;
    }
    return months.values.any((c) => c[0] >= 4 || (c[0] >= 3 && c[1] >= 2));
  }

  /// Applies [f] to [g] on Lagos day [today].
  static FollowUpResult apply(GuestWorkState g, FollowUpInput f, {required String today}) {
    // The first visit counts as attendance: a Wednesday visit as a Wednesday,
    // any other day as a Sunday service.
    final sundays = {...g.sundayDates};
    final wednesdays = {...g.wednesdayDates};
    if (g.serviceDate.isNotEmpty && !sundays.contains(g.serviceDate) && !wednesdays.contains(g.serviceDate)) {
      (LagosTime.isWednesday(g.serviceDate) ? wednesdays : sundays).add(g.serviceDate);
    }
    if (f.attendedSunday) sundays.add(f.sundayDate);
    if (f.attendedWednesday) wednesdays.add(f.wednesdayDate);

    final isFirstCall = !g.hasFollowUps;
    final onTime = isFirstCall &&
        g.serviceDate.isNotEmpty &&
        LagosTime.daysBetween(g.serviceDate, today) <= firstCallWindowDays;
    final count = g.followUpCount + 1;
    final attended = f.attendedSunday || f.attendedWednesday;
    final before = g.status.isEmpty ? newGuest : g.status;

    // Status order: Member > Not interested > Returning > Contacted > Unreachable > unchanged.
    String status;
    if (before == member || qualifies(sundays, wednesdays)) {
      status = member;
    } else if (before == notInterested || f.outcome == notInterested) {
      status = notInterested;
    } else if (before == returning || attended) {
      status = returning;
    } else if (before == contacted || f.outcome == 'Reached') {
      status = contacted;
    } else if (count >= unreachableAfter) {
      status = unreachable;
    } else {
      status = before;
    }

    final becameMember = before != member && status == member;
    var points = onTime ? firstCallPoints : followUpPoints;
    points += ((f.attendedSunday ? 1 : 0) + (f.attendedWednesday ? 1 : 0)) * attendancePoints;
    if (f.team.isNotEmpty && g.teamJoined.isEmpty) points += teamJoinPoints;
    if (becameMember) points += memberPoints;

    return FollowUpResult(
      points: points,
      status: status,
      followUpCount: count,
      isFirstCall: isFirstCall,
      becameMember: becameMember,
      teamJoined: f.team.isNotEmpty ? f.team : g.teamJoined,
      sundayDates: sundays.toList()..sort(),
      wednesdayDates: wednesdays.toList()..sort(),
    );
  }
}
