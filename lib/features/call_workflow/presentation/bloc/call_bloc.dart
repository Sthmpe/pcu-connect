import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/i_call_repository.dart';
import 'call_event.dart';
import 'call_state.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final ICallRepository _callRepository;

  CallBloc({required ICallRepository callRepository})
    : _callRepository = callRepository,
      super(const CallInitialState()) {
    on<SubmitCallFeedbackEvent>(_onSubmitCallFeedback);
  }

  Future<void> _onSubmitCallFeedback(
    SubmitCallFeedbackEvent event,
    Emitter<CallState> emit,
  ) async {
    emit(const CallSubmittingState());
    try {
      await _callRepository.submitCallFeedback(event.interaction);
      emit(const CallSubmittedSuccessState());
    } catch (e) {
      emit(CallSubmittedFailureState(e.toString()));
    }
  }
}
