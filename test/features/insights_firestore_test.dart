import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/utils/lagos_time.dart';
import 'package:workflow/data/firestore/firestore_guest_repository.dart';
import 'package:workflow/data/firestore/firestore_team_repository.dart';
import 'package:workflow/domain/entities/worker_user.dart';
import 'package:workflow/domain/insight_rules.dart';
import 'package:workflow/domain/repositories/i_auth_repository.dart';
import 'package:workflow/domain/repositories/i_team_repository.dart';

class _Auth implements IAuthRepository {
  @override
  final WorkerUser? currentUser;
  _Auth(this.currentUser);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Accounts implements ITeamRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const users = [
  InsightUser(id: 'W001', email: 'boss@x.com', name: 'Boss', isAdmin: true, active: true),
  InsightUser(id: 'W005', email: 'david@x.com', name: 'David Olanite', isAdmin: false, active: true),
  InsightUser(id: 'W002', email: 'ada@x.com', name: 'Ada', isAdmin: false, active: true),
  InsightUser(id: 'W004', email: 'paused@x.com', name: 'Paused', isAdmin: false, active: false),
];

void main() {
  group('InsightRules (same as Api.gs)', () {
    // G1: first visit 1 Oct, first call 3 Oct (on time), then a Sunday and a team join.
    // G2: first visit 2 Oct, first call 9 Oct (late). G3: old guest who became a member in Oct.
    // G4: the admin's own guest.
    const guests = [
      InsightGuest(id: 'G1', serviceDate: '2026-10-01', month: '2026-10', assignedTo: 'david@x.com', status: 'Returning', followUpCount: 2),
      InsightGuest(id: 'G2', serviceDate: '2026-10-02', month: '2026-10', assignedTo: 'david@x.com', status: 'Contacted', followUpCount: 1),
      InsightGuest(id: 'G3', serviceDate: '2026-08-02', month: '2026-08', assignedTo: 'ada@x.com', status: 'Member', memberSinceMonth: '2026-10'),
      InsightGuest(id: 'G4', serviceDate: '2026-10-05', month: '2026-10', assignedTo: 'boss@x.com', status: 'New guest'),
      InsightGuest(id: 'G5', serviceDate: '2026-10-06', month: '2026-10', assignedTo: 'ada@x.com', status: 'New guest'),
    ];
    final followUps = [
      InsightFollowUp(guestId: 'G1', worker: 'david@x.com', callDate: '2026-10-03', createdAt: DateTime.utc(2026, 10, 3)),
      InsightFollowUp(guestId: 'G1', worker: 'david@x.com', callDate: '2026-10-10', createdAt: DateTime.utc(2026, 10, 10), attendedSunday: true, team: 'Workforce'),
      InsightFollowUp(guestId: 'G2', worker: 'david@x.com', callDate: '2026-10-09', createdAt: DateTime.utc(2026, 10, 9)),
      InsightFollowUp(guestId: 'G3', worker: 'ada@x.com', callDate: '2026-09-01', createdAt: DateTime.utc(2026, 9, 1), team: 'Evangelism'),
      InsightFollowUp(guestId: 'G3', worker: 'ada@x.com', callDate: '2026-10-04', createdAt: DateTime.utc(2026, 10, 4), team: 'Workforce'),
      InsightFollowUp(guestId: 'G4', worker: 'boss@x.com', callDate: '2026-10-06', createdAt: DateTime.utc(2026, 10, 6)),
    ];

    test('points: first call on time 10, else 5, attendance 10, first team join 20, members 30 in their month', () {
      final p = InsightRules.points('2026-10', guests, InsightRules.byGuest(followUps));
      expect(p['david@x.com']!.points, 10 + (5 + 10 + 20) + 5);
      expect(p['david@x.com']!.firstCalls, 1);
      expect(p['ada@x.com']!.points, 5 + 30); // G3's team join was in September
      expect(p['ada@x.com']!.teamJoins, 0);
      expect(p['ada@x.com']!.members, 1);
    });

    test('team stats per person', () {
      final team = InsightRules.team('2026-10', guests, followUps, users);
      final david = team.firstWhere((m) => m.email == 'david@x.com');
      expect([david.guests, david.contacted, david.followUps, david.inTeam, david.calledWithin3Days, david.points], [2, 2, 3, 1, 1, 50]);
      final ada = team.firstWhere((m) => m.email == 'ada@x.com');
      expect([ada.guests, ada.contacted, ada.members, ada.points], [1, 0, 0, 35]);
      expect(team.length, 4);
      expect(team.firstWhere((m) => m.email == 'boss@x.com').role, 'Admin');
    });

    test('dashboard totals and top workers never include admins', () {
      final d = InsightRules.dashboard('2026-10', guests, followUps, users);
      expect([d.guests, d.called, d.members, d.inTeam, d.followUps], [4, 3, 0, 1, 4]);
      expect(d.topWorkers.map((w) => w.email), ['ada@x.com', 'david@x.com']);
    });

    test('ranking: admins and paused workers left out, ties share a rank, workers see entries', () {
      final entries = {'david@x.com': (name: 'David Olanite', points: 50), 'ada@x.com': (name: 'Ada', points: 50)};
      final asAdmin = InsightRules.ranking('2026-10', entries, 'boss@x.com', users: users);
      expect(asAdmin.entries.map((e) => e.email), ['ada@x.com', 'david@x.com']);
      expect(asAdmin.entries.map((e) => e.rank), [1, 1]);
      expect(asAdmin.me, isNull);
      final asWorker = InsightRules.ranking('2026-10', {...entries, 'new@x.com': (name: 'New', points: 5)}, 'new@x.com');
      expect(asWorker.me!.rank, 3);
    });
  });

  group('Firestore repositories', () {
    final today = LagosTime.today();
    late FakeFirebaseFirestore db;
    setUp(() async {
      db = FakeFirebaseFirestore();
      await db.doc('users/david@x.com').set({'id': 'W005', 'name': 'David Olanite', 'role': 'worker', 'active': true});
      await db.doc('users/boss@x.com').set({'id': 'W001', 'name': 'Boss', 'role': 'admin', 'active': true});
      await db.doc('guests/G1').set({'name': 'Guest One', 'serviceDate': today, 'month': today.substring(0, 7),
        'assignedTo': 'david@x.com', 'assignedName': 'David Olanite', 'membershipStatus': 'New guest', 'followUpCount': 0});
    });

    test('a save shows on the ranking and the dashboard at once, with no sheet sync', () async {
      const david = WorkerUser(id: 'W005', name: 'David Olanite', email: 'david@x.com', phone: '', role: 'Worker', active: true);
      const boss = WorkerUser(id: 'W001', name: 'Boss', email: 'boss@x.com', phone: '', role: 'Admin', active: true);
      final saved = await FirestoreGuestRepository(db: db, authRepository: _Auth(david)).logFollowUp(
          guestId: 'G1', outcome: 'Reached', note: '', attendedSunday: false, attendedWednesday: false, team: '');
      expect(saved.data!['pointsEarned'], 10);

      final teamRepo = FirestoreTeamRepository(db: db, authRepository: _Auth(david), accounts: _Accounts());
      final ranking = await teamRepo.fetchRanking(month: today.substring(0, 7));
      expect(ranking.data!.me!.points, 10);

      final adminRepo = FirestoreTeamRepository(db: db, authRepository: _Auth(boss), accounts: _Accounts());
      final dash = await adminRepo.fetchDashboard(month: today.substring(0, 7));
      expect([dash.data!.guests, dash.data!.called], [1, 1]);
      expect(dash.data!.topWorkers.single.points, 10);
      final team = await adminRepo.fetchTeam(month: today.substring(0, 7));
      expect(team.data!.firstWhere((m) => m.email == 'david@x.com').id, 'W005');
      final adminRanking = await adminRepo.fetchRanking(month: today.substring(0, 7));
      expect(adminRanking.data!.entries.map((e) => e.email), ['david@x.com']);
    });
  });
}
