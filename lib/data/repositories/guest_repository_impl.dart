import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/storage/local_cache.dart';
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
    final idToken = _authRepository.currentIdToken ?? 'mock_token';
    final payload = <String, dynamic>{
      if (month != null) 'month': month,
      if (filter != null) 'filter': filter,
    };

    final result = await _apiClient.postAction(
      action: 'guests',
      idToken: idToken,
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
    final idToken = _authRepository.currentIdToken ?? 'mock_token';
    final result = await _apiClient.postAction(
      action: 'guest',
      idToken: idToken,
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
    final now = DateTime.now();

    // Business rule validation: Reject future attendance dates!
    if (attendedSunday && sundayDate != null) {
      if (sundayDate.isAfter(DateTime(now.year, now.month, now.day, 23, 59))) {
        return const ApiResult.failure(
          ValidationFailure('Attendance date cannot be in the future.'),
        );
      }
    }

    if (attendedWednesday && wednesdayDate != null) {
      if (wednesdayDate.isAfter(DateTime(now.year, now.month, now.day, 23, 59))) {
        return const ApiResult.failure(
          ValidationFailure('Attendance date cannot be in the future.'),
        );
      }
    }

    final idToken = _authRepository.currentIdToken ?? 'mock_token';
    final result = await _apiClient.postAction(
      action: 'logFollowUp',
      idToken: idToken,
      payload: {
        'guestId': guestId,
        'outcome': outcome,
        'note': note,
        'attendedSunday': attendedSunday,
        'sundayDate': sundayDate?.toIso8601String().substring(0, 10),
        'attendedWednesday': attendedWednesday,
        'wednesdayDate': wednesdayDate?.toIso8601String().substring(0, 10),
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
