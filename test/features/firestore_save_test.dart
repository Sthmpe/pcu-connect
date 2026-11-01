import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/core/utils/lagos_time.dart';
import 'package:workflow/data/firestore/firestore_guest_repository.dart';
import 'package:workflow/domain/entities/worker_user.dart';
import 'package:workflow/domain/repositories/i_auth_repository.dart';

class _Auth implements IAuthRepository {
  @override
  final WorkerUser? currentUser;
  _Auth(this.currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const david = WorkerUser(id: 'W005', name: 'David Olanite', email: 'David@X.com ', phone: '', role: 'Worker', active: true);
const ada = WorkerUser(id: 'W002', name: 'Ada', email: 'ada@x.com', phone: '', role: 'Worker', active: true);
const boss = WorkerUser(id: 'W001', name: 'Boss', email: 'boss@x.com', phone: '', role: 'Admin', active: true);

void main() {
  late FakeFirebaseFirestore db;
  final today = LagosTime.today();

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('guests').doc('G1').set({
      'name': 'Guest One',
      'phone': '0803',
      'serviceDate': today,
      'month': today.substring(0, 7),
      'assignedTo': 'david@x.com',
      'assignedName': 'David Olanite',
      'membershipStatus': 'New guest',
      'followUpCount': 0,
      'firstCallAt': null,
      'sundayDates': <String>[],
      'wednesdayDates': <String>[],
    });
    await db.collection('guests').doc('G9').set({'name': 'Nobody', 'assignedTo': '', 'followUpCount': 0});
  });

  FirestoreGuestRepository repo(WorkerUser user) =>
      FirestoreGuestRepository(db: db, authRepository: _Auth(user));

  Future<ApiResult<Map<String, dynamic>>> log(WorkerUser user, String guestId,
          {String outcome = 'Reached', String note = 'Lovely chat', String team = ''}) =>
      repo(user).logFollowUp(
        guestId: guestId,
        outcome: outcome,
        note: note,
        attendedSunday: false,
        attendedWednesday: false,
        team: team,
      );

  test('a worker save writes the follow-up and the guest work fields together', () async {
    final r = await log(david, 'G1', team: 'Workforce');
    expect(r.isSuccess, isTrue, reason: r.failure?.message);
    expect(r.data!['pointsEarned'], 10 + 20); // first call on time + team join
    expect(r.data!['pendingSync'], isFalse);

    final fu = (await db.collection('followUps').get()).docs.single.data();
    expect(fu['worker'], 'david@x.com');
    expect(fu['loggedBy'], 'david@x.com');
    expect(fu['callDate'], today);
    expect(fu['syncedToSheet'], isFalse);
    expect(fu['points'], 30);

    final g = (await db.collection('guests').doc('G1').get()).data()!;
    expect(g['followUpCount'], 1);
    expect(g['callStatus'], 'Reached');
    expect(g['membershipStatus'], 'Contacted');
    expect(g['lastFeedback'], 'Lovely chat');
    expect(g['teamJoined'], 'Workforce');
    expect(g['lastFollowUpId'], (await db.collection('followUps').get()).docs.single.id);
    expect(g['name'], 'Guest One');
    expect(g['assignedTo'], 'david@x.com');
  });

  test('admin logs on behalf: the worker gets the credit, the guest stays assigned', () async {
    final r = await log(boss, 'G1', outcome: 'No answer', note: '');
    expect(r.isSuccess, isTrue, reason: r.failure?.message);
    final fu = (await db.collection('followUps').get()).docs.single.data();
    expect(fu['worker'], 'david@x.com');
    expect(fu['loggedBy'], 'boss@x.com');
    final g = (await db.collection('guests').doc('G1').get()).data()!;
    expect(g['assignedTo'], 'david@x.com');
    expect(g['followUpCount'], 1);

    final detail = await repo(boss).fetchGuestDetail('G1');
    expect(detail.data!.history.single.loggedByAdmin, isTrue);
    expect(detail.data!.history.single.workerName, 'David Olanite');
  });

  test('a worker cannot log for another worker\'s guest; nobody logs for an unassigned guest', () async {
    final r = await log(ada, 'G1');
    expect(r.isFailure, isTrue);
    expect(r.failure!.message, 'This guest is assigned to someone else.');
    final none = await log(boss, 'G9');
    expect(none.failure!.message, 'Assign this guest to a worker before logging a follow-up.');
    expect((await db.collection('followUps').get()).docs, isEmpty);
  });

  test('future attendance is refused before anything is written', () async {
    final r = await repo(david).logFollowUp(
      guestId: 'G1',
      outcome: 'Reached',
      note: '',
      attendedSunday: true,
      sundayDate: DateTime.now().add(const Duration(days: 3)),
      attendedWednesday: false,
      team: '',
    );
    expect(r.failure?.message, 'Attendance date cannot be in the future.');
    expect((await db.collection('followUps').get()).docs, isEmpty);
  });

  test('the second save is a follow-up (5) and counts up', () async {
    await log(david, 'G1');
    final r = await log(david, 'G1', outcome: 'No answer', note: '');
    expect(r.data!['pointsEarned'], 5);
    final g = (await db.collection('guests').doc('G1').get()).data()!;
    expect(g['followUpCount'], 2);
    expect(g['callStatus'], 'No answer');
    expect(g['membershipStatus'], 'Contacted');
  });
}
