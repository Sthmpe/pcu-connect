import 'package:equatable/equatable.dart';

abstract class TeamEvent extends Equatable {
  const TeamEvent();

  @override
  List<Object?> get props => [];
}

class LoadTeamMembersEvent extends TeamEvent {
  final String campusId;
  final String teamId;

  const LoadTeamMembersEvent({required this.campusId, required this.teamId});

  @override
  List<Object?> get props => [campusId, teamId];
}

class ToggleWorkerAvailabilityEvent extends TeamEvent {
  final String membershipId;
  final String status;
  final String campusId;
  final String teamId;

  const ToggleWorkerAvailabilityEvent({
    required this.membershipId,
    required this.status,
    required this.campusId,
    required this.teamId,
  });

  @override
  List<Object?> get props => [membershipId, status, campusId, teamId];
}
