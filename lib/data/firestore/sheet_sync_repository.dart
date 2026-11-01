import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../domain/entities/sheet_sync.dart';
import '../../domain/repositories/i_auth_repository.dart';

/// The HOD's view of the sheet sync: meta/sync from Firestore (admins only)
/// and the "Sync to sheet" action on the Apps Script API.
abstract class ISheetSyncRepository {
  Stream<SheetSyncStatus> watch();

  Future<ApiResult<SheetSyncResult>> syncNow();
}

class SheetSyncRepository implements ISheetSyncRepository {
  final FirebaseFirestore _db;
  final ApiClient _apiClient;
  final IAuthRepository _auth;

  SheetSyncRepository({
    required FirebaseFirestore db,
    required ApiClient apiClient,
    required IAuthRepository authRepository,
  })  : _db = db,
        _apiClient = apiClient,
        _auth = authRepository;

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  /// Reads meta/sync as the app shows it.
  static SheetSyncStatus fromDoc(Map<String, dynamic>? d) {
    if (d == null) return const SheetSyncStatus();
    final result = d['lastResult'];
    final ok = result is! Map || result['ok'] != false;
    return SheetSyncStatus(
      lastSyncedAt: _date(d['lastSheetSyncAt']),
      running: d['running'] == true,
      lastOk: ok,
      lastError: ok ? null : result['error']?.toString(),
      sheetUrl: (d['sheetUrl'] ?? '').toString(),
    );
  }

  @override
  Stream<SheetSyncStatus> watch() =>
      _db.collection('meta').doc('sync').snapshots().map((s) => fromDoc(s.data()));

  @override
  Future<ApiResult<SheetSyncResult>> syncNow() async {
    final result = await _apiClient.postAuthed(
      action: 'syncNow',
      getToken: _auth.getIdToken,
      payload: const {},
    );
    if (result.isFailure) {
      final failure = result.failure!;
      if (failure.code == 'BUSY') {
        return const ApiResult.failure(ServerFailure('A sync is already running. Try again in a minute.', 'BUSY'));
      }
      if (failure is NetworkFailure) {
        return const ApiResult.failure(NetworkFailure('You are offline. Sync to sheet needs a connection.'));
      }
      return ApiResult.failure(failure);
    }
    final data = result.data;
    if (data is! Map<String, dynamic>) {
      return const ApiResult.failure(ServerFailure('We could not sync to the sheet. Try again.'));
    }
    return ApiResult.success(SheetSyncResult(
      followUps: (data['followUps'] as num?)?.toInt() ?? 0,
      guests: (data['guests'] as num?)?.toInt() ?? 0,
      followUpGuests: (data['followUpGuests'] as num?)?.toInt() ?? 0,
      sheetUrl: (data['sheetUrl'] ?? '').toString(),
    ));
  }
}
