import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/storage/local_cache.dart';
import '../../core/utils/lagos_time.dart';
import '../../domain/follow_up_rules.dart';
import '../../domain/entities/guest_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_guest_repository.dart';

class GuestRepositoryImpl implements IGuestRepository {
  final ApiClient _apiClient;
  final IAuthRepository _authRepository;
  final LocalCache _localCache;

  GuestRepositoryImpl({
    required ApiClient apiClient,
    required IAuthRepository authRepository,
    required LocalCache localCache,
  })  : _apiClient = apiClient,
        _authRepository = authRepository,
        _localCache = localCache;

  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) => null;

  @override
  List<GuestEntity>? getCachedGuests({String? month}) {
    final key = 'guests.${month ?? 'current'}';
    final entry = _localCache.read(key);
    if (entry != null && entry.data is List) {
      return (entry.data as List)
          .whereType<Map<String, dynamic>>()
          .map(GuestEntity.fromJson)
          .toList();
    }
    return null;
  }

  @override
  Future<ApiResult<List<GuestEntity>>> fetchGuests({
    String? month,
    String? filter,
  }) async {
    final payload = <String, dynamic>{
      if (month != null) 'month': month,
      if (filter != null) 'filter': filter,
    };

    final result = await _apiClient.postAuthed(
      action: 'guests',
      getToken: _authRepository.getIdToken,
      payload: payload,
    );

    if (result.isSuccess) {
      try {
        final data = result.data;
        List rawList = const [];
        if (data is Map<String, dynamic> && data['guests'] is List) {
          rawList = data['guests'] as List;
        } else if (data is List) {
          rawList = data;
        }
        await _localCache.write('guests.${month ?? 'current'}', rawList);

        final guests = rawList
            .whereType<Map<String, dynamic>>()
            .map(GuestEntity.fromJson)
            .toList();
        return ApiResult.success(guests);
      } catch (e) {
        return ApiResult.failure(ServerFailure(e.toString()));
      }
    } else {
      final cached = getCachedGuests(month: month);
      if (cached != null && cached.isNotEmpty) {
        return ApiResult.success(cached);
      }
      return ApiResult.failure(result.failure!);
    }
  }

  @override
  Future<ApiResult<GuestEntity>> fetchGuestDetail(String guestId) async {
    final result = await _apiClient.postAuthed(
      action: 'guest',
      getToken: _authRepository.getIdToken,
      payload: {'id': guestId},
    );

    if (result.isSuccess) {
      try {
        final guest =
            GuestEntity.fromJson(result.data as Map<String, dynamic>);
        return ApiResult.success(guest);
      } catch (e) {
        return ApiResult.failure(ServerFailure(e.toString()));
      }
    } else {
      return ApiResult.failure(result.failure!);
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> logFollowUp({
    required String guestId,
    required String outcome,
    required String note,
    required bool attendedSunday,
    DateTime? sundayDate,
    required bool attendedWednesday,
    DateTime? wednesdayDate,
    required String team,
  }) async {
    // Same checks as the backend, with Lagos days (not the device's time zone).
    final sunday = attendedSunday && sundayDate != null ? LagosTime.pickedDay(sundayDate) : '';
    final wednesday = attendedWednesday && wednesdayDate != null ? LagosTime.pickedDay(wednesdayDate) : '';
    final invalid = FollowUpRules.validate(
      FollowUpInput(
        outcome: outcome,
        note: note,
        attendedSunday: attendedSunday,
        sundayDate: sunday,
        attendedWednesday: attendedWednesday,
        wednesdayDate: wednesday,
        team: team,
      ),
      today: LagosTime.today(),
    );
    if (invalid != null) return ApiResult.failure(ValidationFailure(invalid));

    final result = await _apiClient.postAuthed(
      action: 'logFollowUp',
      getToken: _authRepository.getIdToken,
      payload: {
        'guestId': guestId,
        'outcome': outcome,
        'note': note,
        'attendedSunday': attendedSunday,
        'sundayDate': sunday.isEmpty ? null : sunday,
        'attendedWednesday': attendedWednesday,
        'wednesdayDate': wednesday.isEmpty ? null : wednesday,
        'team': team,
      },
    );

    if (result.isSuccess) {
      return ApiResult.success(
        result.data is Map<String, dynamic>
            ? result.data as Map<String, dynamic>
            : {},
      );
    } else {
      return ApiResult.failure(result.failure!);
    }
  }
}
