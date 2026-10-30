import '../../domain/models/guest_model.dart';
import '../../domain/repositories/i_guest_repository.dart';
import '../datasources/guest_remote_datasource.dart';

class GuestRepositoryImpl implements IGuestRepository {
  final GuestRemoteDatasource _remoteDatasource;

  GuestRepositoryImpl({GuestRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? GuestRemoteDatasource();

  @override
  Future<List<GuestModel>> fetchAssignedGuests({
    required String operatorId,
    String? stageFilter,
  }) {
    return _remoteDatasource.getAssignedGuests(
      operatorId: operatorId,
      stageFilter: stageFilter,
    );
  }

  @override
  Future<List<GuestModel>> fetchAllUnitContacts({
    required String unitId,
    String? stageFilter,
  }) {
    return _remoteDatasource.getAllUnitContacts(
      unitId: unitId,
      stageFilter: stageFilter,
    );
  }

  @override
  Future<GuestModel?> fetchContactDetail(String contactId) {
    return _remoteDatasource.getContactDetail(contactId);
  }

  @override
  Future<void> updateContactStage({
    required String contactId,
    required String currentStage,
    DateTime? contactedAt,
    DateTime? returnedAt,
  }) {
    return _remoteDatasource.updateContactStage(
      contactId: contactId,
      currentStage: currentStage,
      contactedAt: contactedAt,
      returnedAt: returnedAt,
    );
  }
}
