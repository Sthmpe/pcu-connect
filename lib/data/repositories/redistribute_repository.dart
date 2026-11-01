import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../domain/repositories/i_auth_repository.dart';

/// Which guests move: outstanding only, every guest never called, or the chosen ones.
enum RedistributeMode { outstanding, uncalled, selected }

class RedistributeShare {
  final String email;
  final String name;
  final int count;
  const RedistributeShare({required this.email, required this.name, required this.count});
}

class RedistributeCandidate {
  final String id;
  final String name;
  final String serviceDate;
  const RedistributeCandidate({required this.id, required this.name, required this.serviceDate});
}

/// A preview or a done move: "12 guests: Worker A 4, Worker B 4, David 4".
class RedistributePlan {
  final int guests;
  final int moved;
  final String text;
  final List<RedistributeShare> shares;
  final List<RedistributeCandidate> candidates;
  const RedistributePlan({
    required this.guests,
    required this.moved,
    required this.text,
    required this.shares,
    required this.candidates,
  });

  static RedistributePlan fromJson(Map<String, dynamic> d) => RedistributePlan(
        guests: (d['guests'] as num?)?.toInt() ?? 0,
        moved: (d['moved'] as num?)?.toInt() ?? 0,
        text: (d['text'] ?? '').toString(),
        shares: [
          for (final p in (d['plan'] as List? ?? const []).whereType<Map>())
            RedistributeShare(
              email: (p['email'] ?? '').toString(),
              name: (p['name'] ?? '').toString(),
              count: (p['count'] as num?)?.toInt() ?? 0,
            ),
        ],
        candidates: [
          for (final c in (d['candidates'] as List? ?? const []).whereType<Map>())
            RedistributeCandidate(
              id: (c['id'] ?? '').toString(),
              name: (c['name'] ?? '').toString(),
              serviceDate: (c['serviceDate'] ?? '').toString(),
            ),
        ],
      );
}

/// The HOD's redistribute (admin-only Apps Script action; the sheet owns
/// assignment, Firestore follows).
abstract class IRedistributeRepository {
  Future<ApiResult<RedistributePlan>> preview({
    required String fromEmail,
    required RedistributeMode mode,
    List<String> guestIds,
    List<String>? toEmails,
  });

  Future<ApiResult<RedistributePlan>> run({
    required String fromEmail,
    required RedistributeMode mode,
    List<String> guestIds,
    List<String>? toEmails,
  });
}

class RedistributeRepository implements IRedistributeRepository {
  final ApiClient _api;
  final IAuthRepository _auth;
  RedistributeRepository({required ApiClient apiClient, required IAuthRepository authRepository})
      : _api = apiClient,
        _auth = authRepository;

  Future<ApiResult<RedistributePlan>> _call(bool preview, String from, RedistributeMode mode, List<String> ids,
      List<String>? to) async {
    final r = await _api.postAuthed(action: 'redistribute', getToken: _auth.getIdToken, payload: {
      'fromEmail': from,
      'mode': mode.name,
      'preview': preview,
      if (mode == RedistributeMode.selected) 'guestIds': ids,
      if (to != null) 'toEmails': to,
    });
    if (r.isFailure) {
      final f = r.failure!;
      return ApiResult.failure(f is NetworkFailure ? const NetworkFailure('You are offline. This needs a connection.') : f);
    }
    final d = r.data;
    return d is Map<String, dynamic>
        ? ApiResult.success(RedistributePlan.fromJson(d))
        : const ApiResult.failure(ServerFailure('Something went wrong. Try again.'));
  }

  @override
  Future<ApiResult<RedistributePlan>> preview({
    required String fromEmail,
    required RedistributeMode mode,
    List<String> guestIds = const [],
    List<String>? toEmails,
  }) =>
      _call(true, fromEmail, mode, guestIds, toEmails);

  @override
  Future<ApiResult<RedistributePlan>> run({
    required String fromEmail,
    required RedistributeMode mode,
    List<String> guestIds = const [],
    List<String>? toEmails,
  }) =>
      _call(false, fromEmail, mode, guestIds, toEmails);
}
