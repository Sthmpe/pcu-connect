import '../core/utils/lagos_time.dart';
import 'entities/insights.dart';
import 'entities/team_member.dart';

/// A guest as the insight rules need it (from guests/{id} in Firestore).
class InsightGuest {
  final String id;
  final String serviceDate; // 'yyyy-MM-dd'
  final String month; // 'yyyy-MM'
  final String assignedTo;
  final String status;
  final String memberSinceMonth; // 'yyyy-MM' or ''
  final String teamJoined;
  final int followUpCount;

  const InsightGuest({
    required this.id,
    required this.serviceDate,
    required this.month,
    required this.assignedTo,
    required this.status,
    this.memberSinceMonth = '',
    this.teamJoined = '',
    this.followUpCount = 0,
  });
}

/// A follow-up as the insight rules need it (from followUps/{id}).
class InsightFollowUp {
  final String guestId;
  final String worker;
  final String callDate; // 'yyyy-MM-dd'
  final DateTime? createdAt; // null while the save waits to sync
  final bool attendedSunday;
  final bool attendedWednesday;
  final String team;

  const InsightFollowUp({
    required this.guestId,
    required this.worker,
    required this.callDate,
    this.createdAt,
    this.attendedSunday = false,
    this.attendedWednesday = false,
    this.team = '',
  });

  String get month => callDate.length >= 7 ? callDate.substring(0, 7) : '';
}

/// A person from users/{email}.
class InsightUser {
  final String id;
  final String email;
  final String name;
  final String phone;
  final bool isAdmin;
  final bool active;

  const InsightUser({
    this.id = '',
    required this.email,
    required this.name,
    this.phone = '',
    required this.isAdmin,
    required this.active,
  });
}

class PointsBreakdown {
  int points = 0;
  int firstCalls = 0;
  int followUps = 0;
  int attendances = 0;
  int teamJoins = 0;
  int members = 0;
}

/// Ranking, team and dashboard numbers from Firestore data, with the same
/// rules as pcuPoints_, pcuWorkerStats_ and pcuDashboard_ in backend/Api.gs.
abstract class InsightRules {
  static const firstCall = 10, followUp = 5, attendance = 10, teamJoin = 20, member = 30;

  /// Follow-ups per guest, oldest first (a save still waiting to sync is newest).
  static Map<String, List<InsightFollowUp>> byGuest(Iterable<InsightFollowUp> followUps) {
    final out = <String, List<InsightFollowUp>>{};
    for (final f in followUps) {
      (out[f.guestId] ??= []).add(f);
    }
    for (final list in out.values) {
      list.sort((a, b) {
        final ta = a.createdAt, tb = b.createdAt;
        if (ta != null && tb != null) return ta.compareTo(tb);
        if (ta == null && tb == null) return a.callDate.compareTo(b.callDate);
        return ta == null ? 1 : -1;
      });
    }
    return out;
  }

  /// True when the first follow-up was within 3 Lagos days of the first visit.
  static bool firstCallOnTime(InsightGuest g, List<InsightFollowUp> list) {
    if (list.isEmpty || list.first.callDate.isEmpty || g.serviceDate.isEmpty) return false;
    return LagosTime.daysBetween(g.serviceDate, list.first.callDate) <= 3;
  }

  /// Calls made, counting older feedback the sheet already held.
  static int callCount(InsightGuest g, List<InsightFollowUp> list) =>
      list.length > g.followUpCount ? list.length : g.followUpCount;

  /// Points per worker for [month] (pcuPoints_).
  static Map<String, PointsBreakdown> points(
    String month,
    Iterable<InsightGuest> guests,
    Map<String, List<InsightFollowUp>> followUps,
  ) {
    final byWorker = <String, PointsBreakdown>{};
    final guestById = {for (final g in guests) g.id: g};
    followUps.forEach((guestId, list) {
      final guest = guestById[guestId];
      var teamSeen = false;
      for (var i = 0; i < list.length; i++) {
        final f = list[i];
        final isTeamJoin = f.team.isNotEmpty && !teamSeen;
        if (f.team.isNotEmpty) teamSeen = true;
        if (f.callDate.isEmpty || f.month != month || f.worker.isEmpty) continue;
        final b = byWorker[f.worker] ??= PointsBreakdown();
        if (i == 0 && guest != null && firstCallOnTime(guest, list)) {
          b.firstCalls++;
          b.points += firstCall;
        } else {
          b.followUps++;
          b.points += followUp;
        }
        final attended = (f.attendedSunday ? 1 : 0) + (f.attendedWednesday ? 1 : 0);
        b.attendances += attended;
        b.points += attended * attendance;
        if (isTeamJoin) {
          b.teamJoins++;
          b.points += teamJoin;
        }
      }
    });
    for (final g in guests) {
      if (g.status == 'Member' && g.memberSinceMonth == month && g.assignedTo.isNotEmpty) {
        final b = byWorker[g.assignedTo] ??= PointsBreakdown();
        b.members++;
        b.points += member;
      }
    }
    return byWorker;
  }

  /// The Team screen for [month] (pcuWorkerStats_), one row per person in users.
  static List<TeamMember> team(
    String month,
    Iterable<InsightGuest> guests,
    Iterable<InsightFollowUp> followUps,
    Iterable<InsightUser> users,
  ) {
    final grouped = byGuest(followUps);
    final pts = points(month, guests, grouped);
    final stats = <String, Map<String, int>>{};
    Map<String, int> bucket(String email) => stats[email] ??= {
          'guests': 0, 'contacted': 0, 'followUps': 0, 'members': 0, 'inTeam': 0, 'calledWithin3Days': 0,
        };
    for (final g in guests) {
      if (g.month != month || g.assignedTo.isEmpty) continue;
      final list = grouped[g.id] ?? const <InsightFollowUp>[];
      final b = bucket(g.assignedTo);
      b['guests'] = b['guests']! + 1;
      if (callCount(g, list) > 0) b['contacted'] = b['contacted']! + 1;
      if (g.status == 'Member') b['members'] = b['members']! + 1;
      if (g.teamJoined.isNotEmpty || list.any((f) => f.team.isNotEmpty)) b['inTeam'] = b['inTeam']! + 1;
      if (firstCallOnTime(g, list)) b['calledWithin3Days'] = b['calledWithin3Days']! + 1;
    }
    for (final f in followUps) {
      if (f.month == month && f.worker.isNotEmpty) {
        final b = bucket(f.worker);
        b['followUps'] = b['followUps']! + 1;
      }
    }
    return [
      for (final u in users)
        TeamMember(
          // users written before the Workers tab ID was copied have none:
          // the email still identifies them (setWorkerActive accepts it).
          id: u.id.isEmpty ? u.email : u.id,
          name: u.name,
          email: u.email,
          phone: u.phone,
          role: u.isAdmin ? 'Admin' : 'Worker',
          active: u.active,
          guests: stats[u.email]?['guests'] ?? 0,
          contacted: stats[u.email]?['contacted'] ?? 0,
          followUps: stats[u.email]?['followUps'] ?? 0,
          members: stats[u.email]?['members'] ?? 0,
          inTeam: stats[u.email]?['inTeam'] ?? 0,
          calledWithin3Days: stats[u.email]?['calledWithin3Days'] ?? 0,
          points: pts[u.email]?.points ?? 0,
        ),
    ];
  }

  /// The Dashboard for [month] (pcuDashboard_ totals and top three workers).
  static DashboardSummary dashboard(
    String month,
    Iterable<InsightGuest> guests,
    Iterable<InsightFollowUp> followUps,
    Iterable<InsightUser> users,
  ) {
    final grouped = byGuest(followUps);
    var total = 0, called = 0, members = 0, inTeam = 0, fus = 0;
    for (final g in guests) {
      if (g.month != month) continue;
      final list = grouped[g.id] ?? const <InsightFollowUp>[];
      total++;
      if (callCount(g, list) > 0) called++;
      if (g.status == 'Member') members++;
      if (g.teamJoined.isNotEmpty || list.any((f) => f.team.isNotEmpty)) inTeam++;
      fus += list.length;
    }
    final pts = points(month, guests, grouped);
    final top = [
      for (final u in users)
        if (!u.isAdmin && pts[u.email] != null)
          TopWorker(email: u.email, name: u.name, members: pts[u.email]!.members, points: pts[u.email]!.points),
    ]..sort((a, b) => b.members != a.members ? b.members - a.members : b.points - a.points);
    return DashboardSummary(
      month: month,
      guests: total,
      called: called,
      members: members,
      inTeam: inTeam,
      followUps: fus,
      topWorkers: top.take(3).toList(),
    );
  }

  /// The leaderboard from the month's ranking entries: active workers only
  /// (never admins), highest points first, ties share a rank.
  static Ranking ranking(
    String month,
    Map<String, ({String name, int points})> entries,
    String myEmail, {
    Iterable<InsightUser>? users,
  }) {
    final rows = <String, ({String name, int points})>{};
    if (users != null) {
      // Admins see every active worker, including those with no points yet.
      for (final u in users) {
        if (u.active && !u.isAdmin) rows[u.email] = (name: u.name, points: entries[u.email]?.points ?? 0);
      }
    } else {
      rows.addAll(entries);
    }
    final list = [
      for (final e in rows.entries) RankingEntry(email: e.key, name: e.value.name, points: e.value.points, rank: 0),
    ]..sort((a, b) => b.points != a.points ? b.points - a.points : a.name.compareTo(b.name));
    final ranked = [
      for (final e in list)
        RankingEntry(email: e.email, name: e.name, points: e.points, rank: 1 + list.where((o) => o.points > e.points).length),
    ];
    RankingEntry? me;
    for (final e in ranked) {
      if (e.email == myEmail) me = e;
    }
    return Ranking(month: month, entries: ranked, me: me);
  }
}
