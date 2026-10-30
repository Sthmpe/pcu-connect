import '../../domain/models/worker_model.dart';
import '../../domain/repositories/i_team_repository.dart';
import '../datasources/team_remote_datasource.dart';

class TeamRepositoryImpl implements ITeamRepository {
  final TeamRemoteDatasource _remoteDatasource;

  TeamRepositoryImpl({TeamRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? TeamRemoteDatasource();

  @override
  Future<List<WorkerModel>> fetchTeamWorkers(String campusId, String teamId) {
    return _remoteDatasource.getTeamWorkers(campusId, teamId);
  }

  @override
  Future<void> updateWorkerAvailability({
    required String membershipId,
    required String status,
  }) {
    return _remoteDatasource.updateAvailability(
      membershipId: membershipId,
      status: status,
    );
  }

  @override
  Future<void> reassignOpenGuests({
    required String fromMembershipId,
    required String toMembershipId,
  }) {
    return _remoteDatasource.reassignOpenAssignments(
      fromMembershipId: fromMembershipId,
      toMembershipId: toMembershipId,
    );
  }
}
