import '../models/worker_model.dart';

abstract class ITeamRepository {
  Future<List<WorkerModel>> fetchTeamWorkers(String campusId, String teamId);

  Future<void> updateWorkerAvailability({
    required String membershipId,
    required String status,
  });

  Future<void> reassignOpenGuests({
    required String fromMembershipId,
    required String toMembershipId,
  });
}
