import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../domain/nudge.dart';
import '../../domain/repositories/i_auth_repository.dart';

abstract class INudgeRepository {
  /// Sends a nudge through the admin-only Apps Script action.
  Future<ApiResult<NudgeResult>> send({required String workerEmail, required int outstanding, String personalLine = ''});

  /// Workers nudged in the last 24 hours: email -> when (Firestore mode; empty otherwise).
  Stream<Map<String, DateTime>> recent();
}

class NudgeRepository implements INudgeRepository {
  final ApiClient _apiClient;
  final IAuthRepository _auth;
  final FirebaseFirestore? _db;
  final DateTime Function() _clock;

  NudgeRepository({
    required ApiClient apiClient,
    required IAuthRepository authRepository,
    FirebaseFirestore? db,
    DateTime Function()? clock,
  })  : _apiClient = apiClient,
        _auth = authRepository,
        _db = db,
        _clock = clock ?? DateTime.now;

  @override
  Future<ApiResult<NudgeResult>> send({required String workerEmail, required int outstanding, String personalLine = ''}) async {
    final result = await _apiClient.postAuthed(
      action: 'nudge',
      getToken: _auth.getIdToken,
      payload: {'workerEmail': workerEmail, 'outstanding': outstanding, 'personalLine': personalLine.trim()},
    );
    if (result.isFailure) {
      final f = result.failure!;
      if (f is NetworkFailure) return const ApiResult.failure(NetworkFailure('You are offline. A nudge needs a connection.'));
      return ApiResult.failure(f);
    }
    final d = result.data;
    if (d is! Map<String, dynamic>) return const ApiResult.failure(ServerFailure('We could not send the nudge. Try again.'));
    return ApiResult.success(NudgeResult(
      inApp: d['inApp'] == true,
      pushSent: (d['pushSent'] as num?)?.toInt() ?? 0,
      emailSent: d['emailSent'] == true,
      nextAt: DateTime.tryParse(d['nextAt']?.toString() ?? ''),
    ));
  }

  @override
  Stream<Map<String, DateTime>> recent() {
    final db = _db;
    if (db == null) return Stream.value(const {});
    return db
        .collection('nudges')
        .where('sentAt', isGreaterThan: Timestamp.fromDate(_clock().subtract(Nudge.every)))
        .snapshots()
        .map((s) => fromDocs(s.docs.map((d) => d.data())))
        .handleError((Object _) {});
  }

  /// The latest nudge per worker.
  static Map<String, DateTime> fromDocs(Iterable<Map<String, dynamic>> docs) {
    final out = <String, DateTime>{};
    for (final d in docs) {
      final at = d['sentAt'];
      final when = at is Timestamp ? at.toDate() : (at is DateTime ? at : null);
      final email = (d['worker'] ?? '').toString();
      if (when == null || email.isEmpty) continue;
      if (out[email] == null || when.isAfter(out[email]!)) out[email] = when;
    }
    return out;
  }
}
