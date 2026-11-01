import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_result.dart';
import '../../core/sync/sync_signals.dart';
import '../../core/utils/lagos_time.dart';
import '../../domain/entities/guest_entity.dart';
import '../../domain/follow_up_rules.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_guest_repository.dart';
import 'firestore_mappers.dart';

/// Guests are read from Firestore (live) and, from phase 2, follow-ups are
/// saved straight to Firestore as one batch: the follow-up plus the guest's
/// work fields. A batch is queued on the device while offline and sent when
/// it reconnects. Workers only ever query their own guests, as the rules require.
class FirestoreGuestRepository implements IGuestRepository {
  final FirebaseFirestore _db;
  final IAuthRepository _auth;

  /// How long a save waits for the server before it counts as "saved on this
  /// phone" (it is still sent once the device is back online).
  final Duration confirmWait;

  /// For the sync chip: saves still on their way, lists still from the device copy.
  final SyncSignals? signals;

  FirestoreGuestRepository({
    required FirebaseFirestore db,
    required IAuthRepository authRepository,
    this.confirmWait = const Duration(seconds: 4),
    this.signals,
  })  : _db = db,
        _auth = authRepository;

  String get _email => (_auth.currentUser?.email ?? '').trim().toLowerCase();

  bool get _isAdmin => _auth.currentUser?.isAdmin ?? false;

  Query<Map<String, dynamic>> _guestsQuery(String month) {
    Query<Map<String, dynamic>> q = _db.collection('guests');
    if (!_isAdmin) q = q.where('assignedTo', isEqualTo: _email);
    return q.where('month', isEqualTo: month);
  }

  static List<GuestEntity> _toGuests(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => FirestoreMappers.guest(d.id, d.data())).toList();

  /// Plain words for Firestore errors.
  static Failure _failure(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return const AuthFailure('You do not have access to these guests.', 'FORBIDDEN');
        case 'unavailable':
        case 'deadline-exceeded':
          return const NetworkFailure('We could not reach the server. Check your connection and try again.');
      }
    }
    return const ServerFailure('We could not load your guests. Try again.');
  }

  @override
  Future<ApiResult<List<GuestEntity>>> fetchGuests({String? month, String? filter}) async {
    if (month == null) return const ApiResult.success([]);
    try {
      return ApiResult.success(_toGuests(await _guestsQuery(month).get()));
    } catch (e) {
      return ApiResult.failure(_failure(e));
    }
  }

  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) =>
      signals == null ? _guestsQuery(month).snapshots().map(_toGuests) : _watchWithSignals(month);

  /// The live list, also telling [signals] while it still shows the device
  /// copy (new assignments on their way). Metadata-only changes are not
  /// passed on as new lists.
  Stream<List<GuestEntity>> _watchWithSignals(String month) {
    final key = Object();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    List<GuestEntity>? last;
    late final StreamController<List<GuestEntity>> out;
    out = StreamController<List<GuestEntity>>(
      onListen: () {
        sub = _guestsQuery(month).snapshots(includeMetadataChanges: true).listen(
          (snap) {
            signals!.listFromCache(key, snap.metadata.isFromCache);
            final guests = _toGuests(snap);
            if (last != null && listEquals(last, guests)) return;
            last = guests;
            out.add(guests);
          },
          onError: out.addError,
        );
      },
      onCancel: () async {
        signals!.listClosed(key);
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  /// Firestore keeps its own offline cache and the live stream serves it first.
  @override
  List<GuestEntity>? getCachedGuests({String? month}) => null;

  @override
  Future<ApiResult<GuestEntity>> fetchGuestDetail(String guestId) async {
    try {
      final doc = await _db.collection('guests').doc(guestId).get();
      final data = doc.data();
      if (data == null) {
        return const ApiResult.failure(ServerFailure('We could not find this guest.'));
      }
      final base = FirestoreMappers.guest(doc.id, data);

      Query<Map<String, dynamic>> q =
          _db.collection('followUps').where('guestId', isEqualTo: guestId);
      // Workers may only read follow-ups credited to them.
      if (!_isAdmin) q = q.where('worker', isEqualTo: _email);
      final snap = await q.orderBy('createdAt', descending: true).get();

      final names = <String, String>{
        if ((data['assignedTo'] ?? '').toString().isNotEmpty)
          data['assignedTo'].toString(): (data['assignedName'] ?? '').toString(),
        if (_auth.currentUser != null) _email: _auth.currentUser!.name,
      };
      // Saves still waiting for the server have no createdAt yet; show them first.
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final ta = a.data()['createdAt'];
          final tb = b.data()['createdAt'];
          if (ta == null || tb == null) return ta == null ? (tb == null ? 0 : -1) : 1;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
      final history = docs
          .map((d) => FirestoreMappers.followUp(d.id, d.data(),
              workerNames: names, pendingSync: d.metadata.hasPendingWrites))
          .toList();

      return ApiResult.success(GuestEntity(
        id: base.id,
        name: base.name,
        phone: base.phone,
        status: base.status,
        daysSinceVisit: base.daysSinceVisit,
        serviceDate: base.serviceDate,
        callCount: base.callCount,
        sundayAttendance: base.sundayAttendance,
        wednesdayAttendance: base.wednesdayAttendance,
        teamJoined: base.teamJoined,
        lastFeedback: base.lastFeedback,
        lastFeedbackDate: base.lastFeedbackDate,
        followUpCount: base.followUpCount,
        month: base.month,
        assignedWorkerName: base.assignedWorkerName,
        history: history,
      ));
    } catch (e) {
      return ApiResult.failure(_failure(e));
    }
  }

  /// Saves a follow-up as one batch: followUps/{new id} plus the guest's work
  /// fields, with points from [FollowUpRules]. An admin saves on behalf of the
  /// assigned worker: the worker gets the credit, loggedBy is the admin, and
  /// the guest stays assigned. Returns pointsEarned, and pendingSync when the
  /// server has not confirmed yet (offline): the save is kept on the device
  /// and sent later.
  @override
  Future<ApiResult<Map<String, dynamic>>> logFollowUp({
    required String guestId,
    required String outcome,
    required String note,
    required bool attendedSunday,
    DateTime? sundayDate,
    required bool attendedWednesday,
    DateTime? wednesdayDate,
    required String team,
  }) async {
    final today = LagosTime.today();
    final input = FollowUpInput(
      outcome: outcome,
      note: note,
      attendedSunday: attendedSunday,
      sundayDate: attendedSunday && sundayDate != null ? LagosTime.pickedDay(sundayDate) : '',
      attendedWednesday: attendedWednesday,
      wednesdayDate: attendedWednesday && wednesdayDate != null ? LagosTime.pickedDay(wednesdayDate) : '',
      team: team,
    );
    final invalid = FollowUpRules.validate(input, today: today);
    if (invalid != null) return ApiResult.failure(ValidationFailure(invalid));

    try {
      final guestRef = _db.collection('guests').doc(guestId);
      final data = (await _readGuest(guestRef)).data();
      if (data == null) {
        return const ApiResult.failure(ServerFailure('We could not find this guest.'));
      }
      final worker = (data['assignedTo'] ?? '').toString().trim().toLowerCase();
      if (worker.isEmpty) {
        return const ApiResult.failure(
            ValidationFailure('Assign this guest to a worker before logging a follow-up.'));
      }
      if (!_isAdmin && worker != _email) {
        return const ApiResult.failure(
            AuthFailure('This guest is assigned to someone else.', 'FORBIDDEN'));
      }

      final result = FollowUpRules.apply(FirestoreMappers.workState(data), input, today: today);
      final followUpRef = _db.collection('followUps').doc();
      // The leaderboard entry moves with the save, for workers only (admins
      // are never ranked). Apps Script rebuilds it nightly from followUps.
      final rankWorker = worker == _email ? !_isAdmin : await _isWorker(worker);
      final batch = _db.batch()
        ..set(followUpRef, {
          'guestId': guestId,
          'worker': worker,
          'loggedBy': _email,
          'callDate': today,
          'month': today.substring(0, 7),
          'outcome': outcome,
          'note': note,
          'attendedSunday': input.attendedSunday,
          'sundayDate': input.sundayDate,
          'attendedWednesday': input.attendedWednesday,
          'wednesdayDate': input.wednesdayDate,
          'team': team,
          'points': result.points,
          'syncedToSheet': false,
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..update(guestRef, {
          'callStatus': outcome,
          'membershipStatus': result.status,
          'followUpCount': FieldValue.increment(1),
          if (result.isFirstCall) 'firstCallAt': FieldValue.serverTimestamp(),
          if (note.isNotEmpty) 'lastFeedback': note,
          if (note.isNotEmpty) 'lastFeedbackDate': FieldValue.serverTimestamp(),
          'teamJoined': result.teamJoined,
          if (result.becameMember && data['memberSince'] == null) 'memberSince': FieldValue.serverTimestamp(),
          'sundayDates': result.sundayDates,
          'wednesdayDates': result.wednesdayDates,
          'lastFollowUpId': followUpRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      if (rankWorker) {
        batch.set(
          _db.collection('rankings').doc(today.substring(0, 7)).collection('entries').doc(worker),
          {
            'email': worker,
            'name': worker == _email
                ? (_auth.currentUser?.name ?? worker)
                : ((data['assignedName'] ?? '').toString().isEmpty ? worker : data['assignedName'].toString()),
            'points': FieldValue.increment(result.points),
            'lastFollowUpId': followUpRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // The batch is applied on the device straight away. Offline, the server
      // answer never comes in time, so the save waits on the device to sync.
      final commit = batch.commit();
      signals?.trackWrite(commit);
      var pendingSync = false;
      try {
        await commit.timeout(confirmWait);
      } on TimeoutException {
        pendingSync = true;
        unawaited(commit.catchError((Object e) => debugPrint('Follow-up $guestId not synced: $e')));
      }
      return ApiResult.success({
        'pointsEarned': result.points,
        'pendingSync': pendingSync,
        'status': result.status,
        'followUpId': followUpRef.id,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const ApiResult.failure(
            AuthFailure('You cannot log a follow-up for this guest.', 'FORBIDDEN'));
      }
      return ApiResult.failure(_failure(e));
    } catch (e) {
      return const ApiResult.failure(ServerFailure('We could not save this follow-up. Try again.'));
    }
  }

  /// True when [email] is a worker (admins can read users). Unknown: false,
  /// so the save never fails over the leaderboard; the nightly rebuild adds it.
  Future<bool> _isWorker(String email) async {
    try {
      final ref = _db.collection('users').doc(email);
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await ref.get(const GetOptions(source: Source.cache));
        if (!snap.exists) snap = await ref.get();
      } catch (_) {
        snap = await ref.get();
      }
      return snap.data()?['role'] == 'worker';
    } catch (_) {
      return false;
    }
  }

  /// The guest from the device cache when it is there (works offline),
  /// otherwise from the server.
  Future<DocumentSnapshot<Map<String, dynamic>>> _readGuest(
      DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } catch (_) {
      // Not cached yet.
    }
    return ref.get();
  }
}
