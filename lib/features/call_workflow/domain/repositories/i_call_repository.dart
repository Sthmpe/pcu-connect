import '../models/call_interaction_model.dart';

abstract class ICallRepository {
  Future<void> submitCallFeedback(CallInteractionModel interaction);
}
