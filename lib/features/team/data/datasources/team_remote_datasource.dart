import '../../../../core/network/supabase_service.dart';
import '../../domain/models/worker_model.dart';

class TeamRemoteDatasource {
  final SupabaseService _supabaseService;

  TeamRemoteDatasource({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  Future<List<WorkerModel>> getTeamWorkers(
    String campusId,
    String teamId,
  ) async {
    final response = await _supabaseService.client
        .from('team_memberships')
        .select('*, profiles!inner(*)')
        .eq('campus_id', campusId)
        .eq('team_id', teamId)
        .eq('active', true);

    final List<WorkerModel> workers = [];
    for (final row in response as List) {
      final membershipId = row['id'] as String;
      final countData = await _supabaseService.client
          .from('assignments')
          .select('id')
          .eq('worker_membership_id', membershipId)
          .eq('status', 'active');

      final openCount = (countData as List).length;
      workers.add(WorkerModel.fromJson(row, openWorkload: openCount));
    }
    return workers;
  }

  Future<void> updateAvailability({
    required String membershipId,
    required String status,
  }) async {
    await _supabaseService.client
        .from('team_memberships')
        .update({
          'availability_status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', membershipId);
  }

  Future<void> reassignOpenAssignments({
    required String fromMembershipId,
    required String toMembershipId,
  }) async {
    await _supabaseService.client
        .from('assignments')
        .update({
          'worker_membership_id': toMembershipId,
          'assignment_method': 'reassigned_by_hod',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('worker_membership_id', fromMembershipId)
        .eq('status', 'active');
  }
}
