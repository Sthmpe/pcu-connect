import '../../core/network/api_result.dart';
import '../entities/insights.dart';
import '../entities/team_member.dart';

/// Team, leaderboard and dashboard data from the Apps Script API.
abstract class ITeamRepository {
  Future<ApiResult<Ranking>> fetchRanking({required String month});

  Future<ApiResult<DashboardSummary>> fetchDashboard({required String month});

  Future<ApiResult<List<TeamMember>>> fetchTeam({required String month});

  Future<ApiResult<TeamMember>> saveWorker({
    required String name,
    required String email,
    required String phone,
    required String role,
    required bool active,
  });

  Future<ApiResult<TeamMember>> setWorkerActive({
    required String id,
    required bool active,
  });
}
