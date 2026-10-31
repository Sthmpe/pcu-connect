import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_result.dart';
import '../../domain/entities/guest_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_guest_repository.dart';
import 'firestore_mappers.dart';

/// Phase 1: guests are read from Firestore (live), while follow-ups are still
/// saved through the Apps Script API ([writer]), which sends the change on to
/// Firestore. Workers only ever query their own guests, as the rules require.
class FirestoreGuestRepository implements IGuestRepository {
  final FirebaseFirestore _db;
  final IAuthRepository _auth;
  final IGuestRepository _writer;

  FirestoreGuestRepository({
    required FirebaseFirestore db,
    required IAuthRepository authRepository,
    required IGuestRepository writer,
  })  : _db = db,
        _auth = authRepository,
        _writer = writer;

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
      _guestsQuery(month).snapshots().map(_toGuests);

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
      final history = snap.docs
          .map((d) => FirestoreMappers.followUp(d.id, d.data(), workerNames: names))
          .toList();

      return ApiResult.success(GuestEntity(
        id: base.id,
        name: base.name,
        phone: base.phone,
        status: base.status,
        daysSinceVisit: base.daysSinceVisit,
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

  /// Phase 1 saves through the Apps Script API.
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
  }) =>
      _writer.logFollowUp(
        guestId: guestId,
        outcome: outcome,
        note: note,
        attendedSunday: attendedSunday,
        sundayDate: sundayDate,
        attendedWednesday: attendedWednesday,
        wednesdayDate: wednesdayDate,
        team: team,
      );
}
