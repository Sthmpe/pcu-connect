import '../../core/network/api_result.dart';
import '../../core/utils/month_utils.dart';
import '../../domain/entities/follow_up_entry.dart';
import '../../domain/entities/guest_entity.dart';
import '../../domain/entities/insights.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/i_guest_repository.dart';
import '../../domain/repositories/i_team_repository.dart';

/// UI work only. Wired in main.dart when AppConfig.useSampleData is true,
/// which is never the case for a release build.
class SampleGuestRepository implements IGuestRepository {
  static GuestEntity _g(String id, String name, String status, int days,
          int calls, int sun, int wed, String team, String fb, String fbDate,
          String worker,
          {int monthsAgo = 0}) =>
      GuestEntity(
        id: id,
        name: name,
        phone: '0803 555 01${id.substring(1).padLeft(2, '0')}',
        status: status,
        daysSinceVisit: days,
        callCount: calls,
        sundayAttendance: sun,
        wednesdayAttendance: wed,
        teamJoined: team,
        lastFeedback: fb,
        lastFeedbackDate: fbDate,
        followUpCount: calls,
        month: MonthUtils.recent(2)[monthsAgo],
        assignedWorkerName: worker,
      );

  final List<GuestEntity> _guests = [
    _g('G1', 'Adaeze Okafor', 'New guest', 4, 0, 1, 0, '', '', '', 'David Olanite'),
    _g('G2', 'Tunde Bakare', 'Contacted', 2, 1, 2, 1, '',
        'Enjoyed the service and will be back on Sunday.', '26 Oct', 'David Olanite'),
    _g('G3', 'Esther Adeyemi', 'Returning', 12, 3, 3, 2, 'Workforce',
        'Asked about joining the Workforce.', '27 Oct', 'Grace Ade'),
    _g('G4', 'Samuel Eze', 'Member', 20, 5, 4, 2, 'Evangelism',
        'Now a member and serving in Evangelism.', '25 Oct', 'David Olanite'),
    _g('G5', 'Ngozi Umeh', 'New guest', 1, 0, 1, 0, '', '', '', 'Tolu Bamidele'),
    _g('G6', 'Femi Ajayi', 'Unreachable', 15, 3, 1, 0, '',
        'Phone was off on three tries.', '20 Oct', 'David Olanite'),
    _g('G7', 'Chiamaka Obi', 'Contacted', 3, 2, 1, 1, '',
        'Asked us to call after work.', '29 Oct', 'Grace Ade'),
    _g('G8', 'Bola Ogun', 'Returning', 40, 4, 2, 1, '',
        'Travelling, back next month.', '12 Sep', 'David Olanite',
        monthsAgo: 1),
  ];

  @override
  Future<ApiResult<List<GuestEntity>>> fetchGuests({String? month, String? filter}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final m = month ?? MonthUtils.current();
    return ApiResult.success(_guests.where((g) => g.month == m).toList());
  }

  @override
  List<GuestEntity>? getCachedGuests({String? month}) => null;

  @override
  Future<ApiResult<GuestEntity>> fetchGuestDetail(String guestId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final g = _guests.firstWhere((g) => g.id == guestId);
    final worker = g.assignedWorkerName ?? '';
    final history = [
      for (var i = 0; i < g.callCount; i++)
        FollowUpEntry(
          id: '${g.id}-$i',
          date: DateTime.now()
              .subtract(Duration(days: 2 + i * 3))
              .toIso8601String()
              .substring(0, 10),
          outcome: i == 1 ? 'No answer' : 'Reached',
          note: i == 0 ? g.lastFeedback : '',
          attendedSunday: i == 0 && g.sundayAttendance > 1,
          attendedWednesday: false,
          team: '',
          workerName: worker,
          loggedByName: i == 1 ? 'Opeyemi Olanite' : worker,
          loggedByAdmin: i == 1,
        ),
    ];
    return ApiResult.success(GuestEntity(
      id: g.id,
      name: g.name,
      phone: g.phone,
      status: g.status,
      daysSinceVisit: g.daysSinceVisit,
      callCount: g.callCount,
      sundayAttendance: g.sundayAttendance,
      wednesdayAttendance: g.wednesdayAttendance,
      teamJoined: g.teamJoined,
      lastFeedback: g.lastFeedback,
      lastFeedbackDate: g.lastFeedbackDate,
      followUpCount: g.followUpCount,
      month: g.month,
      assignedWorkerName: g.assignedWorkerName,
      history: history,
    ));
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
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return const ApiResult.success({'pointsEarned': 15});
  }
}

class SampleTeamRepository implements ITeamRepository {
  final List<TeamMember> _team = [
    const TeamMember(id: 'W001', name: 'Grace Ade', email: 'grace@example.com',
        role: 'Worker', active: true, guests: 8, contacted: 7, followUps: 14,
        members: 3, inTeam: 2, calledWithin3Days: 6, points: 320),
    const TeamMember(id: 'W005', name: 'David Olanite', email: 'davidolanite0@gmail.com',
        role: 'Worker', active: true, guests: 6, contacted: 5, followUps: 12,
        members: 2, inTeam: 2, calledWithin3Days: 5, points: 280),
    const TeamMember(id: 'W003', name: 'Tolu Bamidele', email: 'tolu@example.com',
        role: 'Worker', active: true, guests: 5, contacted: 3, followUps: 7,
        members: 1, inTeam: 1, calledWithin3Days: 3, points: 240),
    const TeamMember(id: 'W004', name: 'Samuel Okon', email: 'samuel@example.com',
        role: 'Worker', active: true, guests: 7, contacted: 3, followUps: 4,
        points: 160),
    const TeamMember(id: 'W006', name: 'Ife Coker', email: 'ife@example.com',
        role: 'Worker', active: false),
    const TeamMember(id: 'W002', name: 'Opeyemi Olanite', email: 'olaniteolanight@gmail.com',
        role: 'Admin', active: true),
  ];

  Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 500));

  @override
  Future<ApiResult<Ranking>> fetchRanking({required String month}) async {
    await _wait();
    final workers = _team.where((w) => w.active && !w.isAdmin).toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    final entries = [
      for (var i = 0; i < workers.length; i++)
        RankingEntry(
          email: workers[i].email,
          name: workers[i].name,
          points: workers[i].points,
          rank: i + 1,
        ),
    ];
    final me = entries.where((e) => e.email == 'davidolanite0@gmail.com');
    return ApiResult.success(
        Ranking(month: month, entries: entries, me: me.isEmpty ? null : me.first));
  }

  @override
  Future<ApiResult<DashboardSummary>> fetchDashboard({required String month}) async {
    await _wait();
    return ApiResult.success(DashboardSummary(
      month: month,
      guests: 7,
      called: 5,
      members: 1,
      inTeam: 2,
      followUps: 18,
      topWorkers: const [
        TopWorker(email: 'grace@example.com', name: 'Grace Ade', members: 3, points: 320),
        TopWorker(email: 'davidolanite0@gmail.com', name: 'David Olanite', members: 2, points: 280),
        TopWorker(email: 'tolu@example.com', name: 'Tolu Bamidele', members: 1, points: 240),
      ],
    ));
  }

  @override
  Future<ApiResult<List<TeamMember>>> fetchTeam({required String month}) async {
    await _wait();
    return ApiResult.success(List.of(_team));
  }

  @override
  Future<ApiResult<TeamMember>> saveWorker({
    required String name,
    required String email,
    required String phone,
    required String role,
    required bool active,
  }) async {
    await _wait();
    final m = TeamMember(
      id: 'W${(_team.length + 1).toString().padLeft(3, '0')}',
      name: name,
      email: email,
      phone: phone,
      role: role,
      active: role == 'Admin' ? true : active,
    );
    _team.add(m);
    return ApiResult.success(m);
  }

  @override
  Future<ApiResult<TeamMember>> setWorkerActive({
    required String id,
    required bool active,
  }) async {
    await _wait();
    final i = _team.indexWhere((m) => m.id == id);
    _team[i] = _team[i].copyWith(active: active);
    return ApiResult.success(_team[i]);
  }
}
