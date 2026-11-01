import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/read_errors.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_result.dart';
import '../../core/utils/lagos_time.dart';
import '../../core/utils/month_utils.dart';
import '../../domain/entities/insights.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/insight_rules.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_team_repository.dart';

/// Firestore mode: ranking, team and dashboard come from Firestore, so a save
/// shows straight away without a sheet sync.
/// - Ranking reads rankings/{month}/entries (kept up to date by every save and
///   rebuilt nightly by Apps Script), because workers may only read their own
///   follow-ups.
/// - Team and Dashboard (HOD only) are worked out from guests, followUps and
///   users with [InsightRules], the same rules as the Apps Script API.
/// Adding a worker and turning one on or off still go through Apps Script
/// ([accounts]), which owns the Workers tab.
class FirestoreTeamRepository implements ITeamRepository {
  final FirebaseFirestore _db;
  final IAuthRepository _auth;
  final ITeamRepository _accounts;

  FirestoreTeamRepository({
    required FirebaseFirestore db,
    required IAuthRepository authRepository,
    required ITeamRepository accounts,
  })  : _db = db,
        _auth = authRepository,
        _accounts = accounts;

  String get _email => (_auth.currentUser?.email ?? '').trim().toLowerCase();
  bool get _isAdmin => _auth.currentUser?.isAdmin ?? false;

  static Failure _failure(Object e) {
    logReadError('team, ranking or dashboard', e);
    if (e is FirebaseException && e.code == 'permission-denied') {
      return const AuthFailure('You do not have access to this.', 'FORBIDDEN');
    }
    if (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded')) {
      return const NetworkFailure('We could not reach the server. Check your connection and try again.');
    }
    return const ServerFailure('We could not load this. Try again.');
  }

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  static InsightGuest guestFrom(String id, Map<String, dynamic> d) {
    final since = _date(d['memberSince']);
    return InsightGuest(
      id: id,
      serviceDate: (d['serviceDate'] ?? '').toString(),
      month: (d['month'] ?? '').toString(),
      assignedTo: (d['assignedTo'] ?? '').toString().trim().toLowerCase(),
      status: (d['membershipStatus'] ?? '').toString(),
      memberSinceMonth: since == null ? '' : LagosTime.day(since).substring(0, 7),
      teamJoined: (d['teamJoined'] ?? '').toString(),
      followUpCount: (d['followUpCount'] as num?)?.toInt() ?? 0,
    );
  }

  static InsightFollowUp followUpFrom(Map<String, dynamic> d) => InsightFollowUp(
        guestId: (d['guestId'] ?? '').toString(),
        worker: (d['worker'] ?? '').toString().trim().toLowerCase(),
        callDate: (d['callDate'] ?? '').toString(),
        createdAt: _date(d['createdAt']),
        attendedSunday: d['attendedSunday'] == true,
        attendedWednesday: d['attendedWednesday'] == true,
        team: (d['team'] ?? '').toString(),
      );

  static InsightUser userFrom(String email, Map<String, dynamic> d) => InsightUser(
        id: (d['id'] ?? '').toString(),
        email: email,
        name: (d['name'] ?? '').toString().isEmpty ? email : d['name'].toString(),
        phone: (d['phone'] ?? '').toString(),
        isAdmin: d['role'] == 'admin',
        active: d['active'] == true,
      );

  Future<List<InsightUser>> _users() async =>
      (await _db.collection('users').get()).docs.map((d) => userFrom(d.id, d.data())).toList();

  /// Guests of [months], plus every member (their points count in the month
  /// they became one, whatever their first visit).
  Future<List<InsightGuest>> _guests(List<String> months) async {
    final byId = <String, InsightGuest>{};
    for (var i = 0; i < months.length; i += 30) {
      final snap = await _db
          .collection('guests')
          .where('month', whereIn: months.sublist(i, i + 30 > months.length ? months.length : i + 30))
          .get();
      for (final d in snap.docs) {
        byId[d.id] = guestFrom(d.id, d.data());
      }
    }
    final members = await _db.collection('guests').where('membershipStatus', isEqualTo: 'Member').get();
    for (final d in members.docs) {
      byId[d.id] = guestFrom(d.id, d.data());
    }
    return byId.values.toList();
  }

  /// Follow-ups from [oldest] on: enough for first calls and first team joins
  /// of every guest in the window.
  Future<List<InsightFollowUp>> _followUps(String oldest) async =>
      (await _db.collection('followUps').where('month', isGreaterThanOrEqualTo: oldest).get())
          .docs
          .map((d) => followUpFrom(d.data()))
          .toList();

  static List<String> _monthsBack(String month, int count) {
    final out = <String>[];
    var m = month;
    for (var i = 0; i < count; i++) {
      out.add(m);
      m = MonthUtils.previous(m);
    }
    return out.reversed.toList();
  }

  @override
  Future<ApiResult<Ranking>> fetchRanking({required String month}) async {
    try {
      final snap = await _db.collection('rankings').doc(month).collection('entries').get();
      final entries = <String, ({String name, int points})>{
        for (final d in snap.docs)
          d.id: (name: (d.data()['name'] ?? d.id).toString(), points: (d.data()['points'] as num?)?.toInt() ?? 0),
      };
      final users = _isAdmin ? await _users() : null;
      return ApiResult.success(InsightRules.ranking(month, entries, _email, users: users));
    } catch (e) {
      return ApiResult.failure(_failure(e));
    }
  }

  @override
  Future<ApiResult<DashboardSummary>> fetchDashboard({required String month}) async {
    try {
      final months = _monthsBack(month, 12);
      final results = await Future.wait([_guests(months), _followUps(months.first), _users()]);
      return ApiResult.success(InsightRules.dashboard(
        month,
        results[0] as List<InsightGuest>,
        results[1] as List<InsightFollowUp>,
        results[2] as List<InsightUser>,
      ));
    } catch (e) {
      return ApiResult.failure(_failure(e));
    }
  }

  @override
  Future<ApiResult<List<TeamMember>>> fetchTeam({required String month}) async {
    try {
      final months = _monthsBack(month, 12);
      final results = await Future.wait([_guests(months), _followUps(months.first), _users()]);
      return ApiResult.success(InsightRules.team(
        month,
        results[0] as List<InsightGuest>,
        results[1] as List<InsightFollowUp>,
        results[2] as List<InsightUser>,
      ));
    } catch (e) {
      return ApiResult.failure(_failure(e));
    }
  }

  @override
  Future<ApiResult<TeamMember>> saveWorker({
    required String name,
    required String email,
    required String phone,
    required String role,
    required bool active,
  }) =>
      _accounts.saveWorker(name: name, email: email, phone: phone, role: role, active: active);

  @override
  Future<ApiResult<TeamMember>> setWorkerActive({required String id, required bool active}) =>
      _accounts.setWorkerActive(id: id, active: active);
}
