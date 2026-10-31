import '../../core/network/api_result.dart';
import '../entities/guest_entity.dart';

abstract class IGuestRepository {
  Future<ApiResult<List<GuestEntity>>> fetchGuests({
    String? month,
    String? filter,
  });

  List<GuestEntity>? getCachedGuests({String? month});

  /// Live guest list for a month, or null when the source cannot push updates
  /// (the Apps Script API). When available, lists refresh on their own.
  Stream<List<GuestEntity>>? watchGuests({required String month});

  Future<ApiResult<GuestEntity>> fetchGuestDetail(String guestId);

  Future<ApiResult<Map<String, dynamic>>> logFollowUp({
    required String guestId,
    required String outcome,
    required String note,
    required bool attendedSunday,
    DateTime? sundayDate,
    required bool attendedWednesday,
    DateTime? wednesdayDate,
    required String team,
  });
}
