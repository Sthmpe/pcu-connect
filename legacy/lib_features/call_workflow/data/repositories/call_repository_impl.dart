import '../../domain/models/call_interaction_model.dart';
import '../../domain/repositories/i_call_repository.dart';
import '../datasources/call_remote_datasource.dart';

class CallRepositoryImpl implements ICallRepository {
  final CallRemoteDatasource _remoteDatasource;

  CallRepositoryImpl({CallRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? CallRemoteDatasource();

  @override
  Future<void> submitCallFeedback(CallInteractionModel interaction) {
    return _remoteDatasource.submitInteraction(interaction);
  }
}
