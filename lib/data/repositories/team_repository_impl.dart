import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../domain/entities/insights.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_team_repository.dart';

class TeamRepositoryImpl implements ITeamRepository {
  final ApiClient _apiClient;
  final IAuthRepository _authRepository;

  TeamRepositoryImpl({
    required ApiClient apiClient,
    required IAuthRepository authRepository,
  })  : _apiClient = apiClient,
        _authRepository = authRepository;

  Future<ApiResult<T>> _call<T>(
    String action,
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic> data) parse,
  ) async {
    final result = await _apiClient.postAuthed(
      action: action,
      getToken: _authRepository.getIdToken,
      payload: payload,
    );
    if (result.isFailure) return ApiResult.failure(result.failure!);
    final data = result.data;
    if (data is! Map<String, dynamic>) {
      return const ApiResult.failure(ServerFailure('Unexpected response.'));
    }
    try {
      return ApiResult.success(parse(data));
    } catch (e) {
      return ApiResult.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<ApiResult<Ranking>> fetchRanking({required String month}) =>
      _call('ranking', {'month': month}, Ranking.fromJson);

  @override
  Future<ApiResult<DashboardSummary>> fetchDashboard({required String month}) =>
      _call('dashboard', {'month': month}, DashboardSummary.fromJson);

  @override
  Future<ApiResult<List<TeamMember>>> fetchTeam({required String month}) =>
      _call(
        'team',
        {'month': month},
        (data) => (data['members'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TeamMember.fromJson)
            .toList(),
      );

  @override
  Future<ApiResult<TeamMember>> saveWorker({
    required String name,
    required String email,
    required String phone,
    required String role,
    required bool active,
  }) =>
      _call(
        'saveWorker',
        {
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
          'active': active,
        },
        TeamMember.fromJson,
      );

  @override
  Future<ApiResult<TeamMember>> setWorkerActive({
    required String id,
    required bool active,
  }) =>
      _call('setWorkerActive', {'id': id, 'active': active}, TeamMember.fromJson);
}
