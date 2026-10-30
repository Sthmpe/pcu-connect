import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/i_team_repository.dart';
import 'team_event.dart';
import 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  final ITeamRepository _teamRepository;

  TeamBloc({required ITeamRepository teamRepository})
    : _teamRepository = teamRepository,
      super(const TeamInitialState()) {
    on<LoadTeamMembersEvent>(_onLoadTeamMembers);
    on<ToggleWorkerAvailabilityEvent>(_onToggleWorkerAvailability);
  }

  Future<void> _onLoadTeamMembers(
    LoadTeamMembersEvent event,
    Emitter<TeamState> emit,
  ) async {
    emit(const TeamLoadingState());
    try {
      final workers = await _teamRepository.fetchTeamWorkers(
        event.campusId,
        event.teamId,
      );
      emit(TeamLoadedState(workers));
    } catch (e) {
      emit(TeamFailureState(e.toString()));
    }
  }

  Future<void> _onToggleWorkerAvailability(
    ToggleWorkerAvailabilityEvent event,
    Emitter<TeamState> emit,
  ) async {
    try {
      await _teamRepository.updateWorkerAvailability(
        membershipId: event.membershipId,
        status: event.status,
      );
      add(LoadTeamMembersEvent(campusId: event.campusId, teamId: event.teamId));
    } catch (e) {
      emit(TeamFailureState(e.toString()));
    }
  }
}
