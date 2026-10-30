import 'package:equatable/equatable.dart';

abstract class CallState extends Equatable {
  const CallState();

  @override
  List<Object?> get props => [];
}

class CallInitialState extends CallState {
  const CallInitialState();
}

class CallSubmittingState extends CallState {
  const CallSubmittingState();
}

class CallSubmittedSuccessState extends CallState {
  const CallSubmittedSuccessState();
}

class CallSubmittedFailureState extends CallState {
  final String errorMessage;

  const CallSubmittedFailureState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
