import 'package:equatable/equatable.dart';
import '../../domain/models/worker_model.dart';

abstract class TeamState extends Equatable {
  const TeamState();

  @override
  List<Object?> get props => [];
}

class TeamInitialState extends TeamState {
  const TeamInitialState();
}

class TeamLoadingState extends TeamState {
  const TeamLoadingState();
}

class TeamLoadedState extends TeamState {
  final List<WorkerModel> workers;

  const TeamLoadedState(this.workers);

  @override
  List<Object?> get props => [workers];
}

class TeamFailureState extends TeamState {
  final String errorMessage;

  const TeamFailureState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
