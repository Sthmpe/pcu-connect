import 'package:intl/intl.dart';
import '../../core/utils/lagos_time.dart';
import '../../domain/entities/follow_up_entry.dart';
import '../../domain/entities/guest_entity.dart';
import '../../domain/entities/worker_user.dart';
import '../../domain/follow_up_rules.dart';

/// Converts Firestore documents (docs/BACKEND_PLAN.md data model) into the
/// app's entities. Pure functions: timestamps arrive as DateTime, so they can
/// be tested without Firestore.
abstract class FirestoreMappers {
  static String _str(dynamic v) => v?.toString() ?? '';

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  static DateTime? _date(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    // Firestore Timestamp, without importing cloud_firestore here.
    try {
      return (v as dynamic)?.toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  static List<String> _days(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  /// Short Lagos date for notes, like the API sends ('26 Oct').
  static String _shortDay(DateTime? d) =>
      d == null ? '' : DateFormat('d MMM').format(d.toUtc().add(LagosTime.offset));

  static GuestEntity guest(String id, Map<String, dynamic> d, {DateTime? clock}) {
    final today = LagosTime.today(clock);
    final thisMonth = today.substring(0, 7);
    final serviceDate = _str(d['serviceDate']);
    final sundayDates = _days(d['sundayDates']).where((s) => s.startsWith(thisMonth)).toList();
    final wednesdayDates = _days(d['wednesdayDates']).where((s) => s.startsWith(thisMonth)).toList();
    final calls = _int(d['followUpCount']);

    return GuestEntity(
      id: id,
      name: _str(d['name']).isEmpty ? 'Guest' : _str(d['name']),
      phone: _str(d['phone']),
      status: _str(d['membershipStatus']).isEmpty ? 'New guest' : _str(d['membershipStatus']),
      daysSinceVisit: serviceDate.isEmpty
          ? 0
          : LagosTime.daysBetween(serviceDate, today).clamp(0, 100000),
      serviceDate: serviceDate,
      callCount: calls,
      sundayAttendance: sundayDates.length,
      wednesdayAttendance: wednesdayDates.length,
      sundayDates: sundayDates,
      wednesdayDates: wednesdayDates,
      teamJoined: _str(d['teamJoined']),
      lastFeedback: _str(d['lastFeedback']),
      lastFeedbackDate: _shortDay(_date(d['lastFeedbackDate'])),
      lastOutcome: _str(d['callStatus']),
      lastCallDate: _str(d['lastCallDate']),
      gender: _str(d['gender']),
      followUpCount: calls,
      month: _str(d['month']),
      assignedWorkerName: _str(d['assignedName']),
    );
  }

  /// A follow-up as shown in the guest history. [workerNames] maps emails to
  /// names when known (the guest's assigned worker at least).
  static FollowUpEntry followUp(String id, Map<String, dynamic> d,
      {Map<String, String> workerNames = const {}, bool pendingSync = false}) {
    final worker = _str(d['worker']);
    final loggedBy = _str(d['loggedBy']).isEmpty ? worker : _str(d['loggedBy']);
    return FollowUpEntry(
      id: id,
      date: _str(d['callDate']),
      outcome: _str(d['outcome']),
      note: _str(d['note']),
      attendedSunday: d['attendedSunday'] == true,
      attendedWednesday: d['attendedWednesday'] == true,
      team: _str(d['team']),
      workerName: workerNames[worker] ?? worker,
      loggedByName: workerNames[loggedBy] ?? '',
      loggedByAdmin: loggedBy != worker,
      pendingSync: pendingSync,
    );
  }

  /// The guest's work fields as the follow-up rules need them.
  static GuestWorkState workState(Map<String, dynamic> d) => GuestWorkState(
        serviceDate: _str(d['serviceDate']),
        status: _str(d['membershipStatus']),
        followUpCount: _int(d['followUpCount']),
        hasFollowUps: d['firstCallAt'] != null,
        teamJoined: _str(d['teamJoined']),
        sundayDates: _days(d['sundayDates']),
        wednesdayDates: _days(d['wednesdayDates']),
        hasMemberSince: d['memberSince'] != null,
      );

  static WorkerUser user(String email, Map<String, dynamic> d) => WorkerUser(
        id: email,
        name: _str(d['name']).isEmpty ? email : _str(d['name']),
        email: email,
        phone: _str(d['phone']),
        role: d['role'] == 'admin' ? 'Admin' : 'Worker',
        active: d['active'] == true,
      );
}
