import '../models/guest_model.dart';

abstract class IGuestRepository {
  Future<List<GuestModel>> fetchAssignedGuests({
    required String operatorId,
    String? stageFilter,
  });

  Future<List<GuestModel>> fetchAllUnitContacts({
    required String unitId,
    String? stageFilter,
  });

  Future<GuestModel?> fetchContactDetail(String contactId);

  Future<void> updateContactStage({
    required String contactId,
    required String currentStage,
    DateTime? contactedAt,
    DateTime? returnedAt,
  });
}
