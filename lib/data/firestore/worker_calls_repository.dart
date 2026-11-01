import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/today_rules.dart';

/// The signed-in worker's own calls, for Today and its daily goal ring.
abstract class IWorkerCallsRepository {
  /// Live list, or null when the source cannot push updates (Apps Script).
  Stream<List<CallRecord>>? watch();
}

/// followUps credited to the signed-in worker (the rules allow exactly this
/// query). Saves still waiting to sync are included straight away.
class FirestoreWorkerCallsRepository implements IWorkerCallsRepository {
  final FirebaseFirestore _db;
  final IAuthRepository _auth;

  FirestoreWorkerCallsRepository({required FirebaseFirestore db, required IAuthRepository authRepository})
      : _db = db,
        _auth = authRepository;

  static CallRecord fromDoc(Map<String, dynamic> d) {
    final created = d['createdAt'];
    return CallRecord(
      guestId: (d['guestId'] ?? '').toString(),
      callDate: (d['callDate'] ?? '').toString(),
      outcome: (d['outcome'] ?? '').toString(),
      loggedBy: (d['loggedBy'] ?? '').toString().trim().toLowerCase(),
      createdAt: created is Timestamp ? created.toDate() : (created is DateTime ? created : null),
    );
  }

  @override
  Stream<List<CallRecord>>? watch() {
    final email = (_auth.currentUser?.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return const Stream.empty();
    return _db
        .collection('followUps')
        .where('worker', isEqualTo: email)
        .snapshots()
        .map((s) => s.docs.map((d) => fromDoc(d.data())).toList());
  }
}

/// Apps Script source: no live call list; Today uses each guest's own
/// lastCallDate and lastOutcome instead.
class NoWorkerCallsRepository implements IWorkerCallsRepository {
  const NoWorkerCallsRepository();

  @override
  Stream<List<CallRecord>>? watch() => null;
}
