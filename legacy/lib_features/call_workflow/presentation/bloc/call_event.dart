import 'package:equatable/equatable.dart';
import '../../domain/models/call_interaction_model.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

class SubmitCallFeedbackEvent extends CallEvent {
  final CallInteractionModel interaction;

  const SubmitCallFeedbackEvent(this.interaction);

  @override
  List<Object?> get props => [interaction];
}
