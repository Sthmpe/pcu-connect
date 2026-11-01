import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../domain/repositories/i_auth_repository.dart';

class AssignPreview {
  final int unassigned;
  final int workers;
  const AssignPreview({required this.unassigned, required this.workers});
}

class AssignResult {
  final int assigned;

  /// "3 guests assigned: David 2, Worker A 1" ('' when none).
  final String summary;
  const AssignResult({required this.assigned, required this.summary});
}

/// The HOD's "Assign guests" (admin-only Apps Script actions; the sheet owns
/// assignment). Dates are Lagos service days, 'yyyy-MM-dd'.
abstract class IAssignRepository {
  Future<ApiResult<AssignPreview>> preview({required String from, required String to});
  Future<ApiResult<AssignResult>> assign({required String from, required String to});
}

class AssignRepository implements IAssignRepository {
  final ApiClient _api;
  final IAuthRepository _auth;
  AssignRepository({required ApiClient apiClient, required IAuthRepository authRepository})
      : _api = apiClient,
        _auth = authRepository;

  Future<ApiResult<Map<String, dynamic>>> _call(String action, String from, String to) async {
    final r = await _api.postAuthed(action: action, getToken: _auth.getIdToken, payload: {'from': from, 'to': to});
    if (r.isFailure) {
      final f = r.failure!;
      return ApiResult.failure(f is NetworkFailure ? const NetworkFailure('You are offline. Assigning needs a connection.') : f);
    }
    final d = r.data;
    return d is Map<String, dynamic> ? ApiResult.success(d) : const ApiResult.failure(ServerFailure('Something went wrong. Try again.'));
  }

  @override
  Future<ApiResult<AssignPreview>> preview({required String from, required String to}) async {
    final r = await _call('assignPreview', from, to);
    if (r.isFailure) return ApiResult.failure(r.failure!);
    return ApiResult.success(AssignPreview(
      unassigned: (r.data!['unassigned'] as num?)?.toInt() ?? 0,
      workers: (r.data!['workers'] as num?)?.toInt() ?? 0,
    ));
  }

  @override
  Future<ApiResult<AssignResult>> assign({required String from, required String to}) async {
    final r = await _call('assignRange', from, to);
    if (r.isFailure) return ApiResult.failure(r.failure!);
    return ApiResult.success(AssignResult(
      assigned: (r.data!['assigned'] as num?)?.toInt() ?? 0,
      summary: (r.data!['summary'] ?? '').toString(),
    ));
  }
}
