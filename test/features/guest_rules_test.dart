import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/core/network/api_client.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/core/storage/local_cache.dart';
import 'package:workflow/data/repositories/guest_repository_impl.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/entities/worker_user.dart';
import 'package:workflow/domain/repositories/i_auth_repository.dart';

class MockAuthRepository implements IAuthRepository {
  @override
  String? get currentIdToken => 'mock_token_david';

  @override
  WorkerUser? get currentUser => null;

  @override
  Future<ApiResult<WorkerUser>> getProfile(String idToken) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<String>> signInWithGoogle() async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Guest Urgency & Performance Colors', () {
    test('new guest within 3 days has blue urgency', () {
      const guest = GuestEntity(
        id: 'G1',
        name: 'Ada Obi',
        phone: '08035550101',
        status: 'New guest',
        daysSinceVisit: 2,
        callCount: 0,
        sundayAttendance: 1,
        wednesdayAttendance: 0,
        teamJoined: '',
        lastFeedback: '',
        lastFeedbackDate: '',
        followUpCount: 0,
        month: 'Oct 2026',
      );
      expect(guest.urgency, GuestUrgency.blue);
    });

    test('guest not called after 3 days has red urgency', () {
      const guest = GuestEntity(
        id: 'G1',
        name: 'Ada Obi',
        phone: '08035550101',
        status: 'New guest',
        daysSinceVisit: 4,
        callCount: 0,
        sundayAttendance: 1,
        wednesdayAttendance: 0,
        teamJoined: '',
        lastFeedback: '',
        lastFeedbackDate: '',
        followUpCount: 0,
        month: 'Oct 2026',
      );
      expect(guest.urgency, GuestUrgency.red);
    });

    test('guest called once has amber urgency', () {
      const guest = GuestEntity(
        id: 'G1',
        name: 'Ada Obi',
        phone: '08035550101',
        status: 'Contacted',
        daysSinceVisit: 5,
        callCount: 1,
        sundayAttendance: 1,
        wednesdayAttendance: 0,
        teamJoined: '',
        lastFeedback: 'Good chat',
        lastFeedbackDate: '26 Oct',
        followUpCount: 1,
        month: 'Oct 2026',
      );
      expect(guest.urgency, GuestUrgency.amber);
    });

    test('guest followed up twice or more has green urgency', () {
      const guest = GuestEntity(
        id: 'G1',
        name: 'Ada Obi',
        phone: '08035550101',
        status: 'Returning',
        daysSinceVisit: 10,
        callCount: 2,
        sundayAttendance: 2,
        wednesdayAttendance: 1,
        teamJoined: '',
        lastFeedback: 'Will be back',
        lastFeedbackDate: '28 Oct',
        followUpCount: 2,
        month: 'Oct 2026',
      );
      expect(guest.urgency, GuestUrgency.green);
    });
  });

  group('Guest Contact URLs', () {
    test('formats clean Nigerian WhatsApp link', () {
      const guest = GuestEntity(
        id: 'G1',
        name: 'Ada Obi',
        phone: '0803 555 0101',
        status: 'New guest',
        daysSinceVisit: 1,
        callCount: 0,
        sundayAttendance: 1,
        wednesdayAttendance: 0,
        teamJoined: '',
        lastFeedback: '',
        lastFeedbackDate: '',
        followUpCount: 0,
        month: 'Oct 2026',
      );
      expect(guest.whatsAppUrl, 'https://wa.me/2348035550101');
      expect(guest.telUrl, 'tel:08035550101');
      expect(guest.initials, 'AO');
    });
  });

  group('Attendance Date Validation', () {
    test('strictly rejects future attendance dates', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = GuestRepositoryImpl(
        apiClient: ApiClient(baseUrl: 'https://example.com'),
        authRepository: MockAuthRepository(),
        localCache: LocalCache(prefs),
      );

      final futureDate = DateTime.now().add(const Duration(days: 2));
      final result = await repo.logFollowUp(
        guestId: 'G1',
        outcome: 'Reached',
        note: 'Note',
        attendedSunday: true,
        sundayDate: futureDate,
        attendedWednesday: false,
        team: '',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure?.message, contains('future'));
    });
  });
}
