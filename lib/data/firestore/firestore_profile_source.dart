import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_result.dart';
import '../../domain/entities/worker_user.dart';
import 'firestore_mappers.dart';

/// Reads the signed-in person's role from users/{email}.
class FirestoreProfileSource {
  static const String notOnTeam = 'You are not on the team yet. Ask your HOD to add you.';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreProfileSource({required FirebaseFirestore db, required FirebaseAuth auth})
      : _db = db,
        _auth = auth;

  Future<ApiResult<WorkerUser>> load() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      return const ApiResult.failure(AuthFailure('Please sign in.', 'UNAUTHENTICATED'));
    }
    try {
      final snap = await _db.collection('users').doc(email).get();
      final data = snap.data();
      if (data == null || data['active'] != true) {
        return const ApiResult.failure(AuthFailure(notOnTeam, 'ACCESS_DENIED'));
      }
      return ApiResult.success(FirestoreMappers.user(email, data));
    } on FirebaseException catch (e) {
      // The rules refuse anyone without an active users document.
      if (e.code == 'permission-denied') {
        return const ApiResult.failure(AuthFailure(notOnTeam, 'ACCESS_DENIED'));
      }
      return const ApiResult.failure(
          NetworkFailure('We could not reach the server. Check your connection and try again.'));
    }
  }
}
