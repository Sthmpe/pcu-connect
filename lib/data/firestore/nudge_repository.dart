import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/utils/read_errors.dart';
import '../../domain/nudge.dart';
import '../../domain/repositories/i_auth_repository.dart';

abstract class INudgeRepository {
  /// Sends a nudge through the admin-only Apps Script action.
  Future<ApiResult<NudgeResult>> send({required String workerEmail, required int outstanding, String personalLine = ''});

  /// Recent nudges on every channel, newest first (Firestore mode; empty otherwise).
  Stream<NudgeHistory> history();

  /// Logs a WhatsApp nudge the HOD just opened (Firestore mode).
  Future<void> logWhatsApp({required String workerEmail, required String workerName, required int outstanding});
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
  Stream<NudgeHistory> history() {
    final db = _db;
    if (db == null) return Stream.value(NudgeHistory.empty);
    return db
        .collection('nudges')
        .orderBy('sentAt', descending: true)
        .limit(300)
        .snapshots()
        .map((s) => fromDocs(s.docs.map((d) => d.data()), now: _clock()))
        .handleError((Object e) => logReadError('nudges', e));
  }

  @override
  Future<void> logWhatsApp({required String workerEmail, required String workerName, required int outstanding}) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('nudges').add({
        'worker': workerEmail,
        'workerName': workerName,
        'sentBy': (_auth.currentUser?.email ?? '').trim().toLowerCase(),
        'sentAt': FieldValue.serverTimestamp(),
        'channel': 'whatsapp',
        'outstanding': outstanding,
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      // Offline, the write waits and syncs; a refused one is only logged.
      logReadError('nudge log', e);
    }
  }

  /// Newest first; a WhatsApp nudge still waiting for its server time counts as now.
  static NudgeHistory fromDocs(Iterable<Map<String, dynamic>> docs, {DateTime? now}) {
    final out = <NudgeLog>[];
    for (final d in docs) {
      final at = d['sentAt'];
      final when = at is Timestamp ? at.toDate() : (at is DateTime ? at : (at == null ? now : null));
      final email = (d['worker'] ?? '').toString();
      if (when == null || email.isEmpty) continue;
      out.add(NudgeLog(worker: email, at: when, channel: (d['channel'] ?? 'app').toString()));
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return NudgeHistory(out);
  }
}
