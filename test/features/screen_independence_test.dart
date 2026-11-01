import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/errors/failures.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/entities/insights.dart';
import 'package:workflow/domain/entities/team_member.dart';
import 'package:workflow/domain/repositories/i_guest_repository.dart';
import 'package:workflow/domain/repositories/i_team_repository.dart';
import 'package:workflow/domain/today_rules.dart';
import 'package:workflow/presentation/common/insights_cubits.dart';
import 'package:workflow/presentation/guests/bloc/guests_bloc.dart';
import 'package:workflow/presentation/guests/bloc/guests_event.dart';
import 'package:workflow/presentation/guests/bloc/guests_filter_cubit.dart';
import 'package:workflow/presentation/guests/bloc/guests_state.dart';

GuestEntity guest(String id, String serviceDate, {int calls = 0, int days = 0, String status = 'New guest'}) => GuestEntity(
      id: id,
      name: 'Guest $id',
      phone: '',
      status: status,
      daysSinceVisit: days,
      serviceDate: serviceDate,
      callCount: calls,
      sundayAttendance: 0,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: calls,
      month: serviceDate.substring(0, 7),
    );

/// Live source with one stream per month, like Firestore.
class _LiveByMonth implements IGuestRepository {
  final streams = <String, StreamController<List<GuestEntity>>>{};
  int cancelled = 0;

  StreamController<List<GuestEntity>> of(String month) =>
      streams[month] ??= StreamController<List<GuestEntity>>.broadcast(onCancel: () => cancelled++);

  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) => of(month).stream;
  @override
  Future<ApiResult<List<GuestEntity>>> fetchGuests({String? month, String? filter}) async => const ApiResult.success([]);
  @override
  List<GuestEntity>? getCachedGuests({String? month}) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One-off source like the Apps Script API.
class _Fetching implements IGuestRepository {
  final data = <String, List<GuestEntity>>{};
  final cached = <String, List<GuestEntity>>{};
  bool fail = false;
  final fetched = <String>[];

  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) => null;
  @override
  Future<ApiResult<List<GuestEntity>>> fetchGuests({String? month, String? filter}) async {
    fetched.add(month!);
    if (fail) return const ApiResult.failure(NetworkFailure('Offline'));
    return ApiResult.success(data[month] ?? const []);
  }

  @override
  List<GuestEntity>? getCachedGuests({String? month}) => cached[month];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Team implements ITeamRepository {
  @override
  Future<ApiResult<DashboardSummary>> fetchDashboard({required String month}) async => ApiResult.success(
      DashboardSummary(month: month, guests: 0, called: 0, members: 0, inTeam: 0, followUps: 0, topWorkers: const []));
  @override
  Future<ApiResult<Ranking>> fetchRanking({required String month}) async => ApiResult.success(Ranking(month: month, entries: const []));
  @override
  Future<ApiResult<List<TeamMember>>> fetchTeam({required String month}) async => const ApiResult.success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  const since = '2026-10-28';
  // Today's months on 1 Nov 2026.
  final todayMonths = TodayRules.months(since: since, today: '2026-11-01');

  group('(a) Today never follows the Guests month', () {
    test('choosing September on Guests leaves Today exactly as it was', () async {
      final repo = _LiveByMonth();
      final bloc = GuestsBloc(guestRepository: repo);
      final guestsFilter = GuestsFilterCubit(month: '2026-11');

      bloc.add(WatchMonthsEvent(todayMonths));
      bloc.add(WatchMonthsEvent([guestsFilter.state.month]));
      await tick();
      repo.of('2026-10').add([guest('O1', '2026-10-28', days: 4), guest('C1', '2026-10-29', calls: 1, days: 3)]);
      repo.of('2026-11').add([guest('N1', '2026-11-01', days: 0)]);
      await tick();
      final before = TodayRules.of(bloc.state.guestsIn(todayMonths), since: since);
      expect(before.outstanding.map((g) => g.id), ['O1']);
      expect(before.fresh.map((g) => g.id), ['N1']);

      // The worker picks September on the Guests screen.
      guestsFilter.selectMonth('2026-09');
      bloc.add(WatchMonthsEvent([guestsFilter.state.month]));
      await tick();
      repo.of('2026-09').add([guest('S1', '2026-09-06', days: 56), guest('S2', '2026-09-13', days: 49)]);
      await tick();

      final after = TodayRules.of(bloc.state.guestsIn(todayMonths), since: since);
      expect(after.outstanding.map((g) => g.id), ['O1']);
      expect(after.fresh.map((g) => g.id), ['N1']);
      expect(bloc.state.guestsOf('2026-09').length, 2, reason: 'the Guests screen still gets September');
      expect(todayMonths, isNot(contains('2026-09')));
      await bloc.close();
      await guestsFilter.close();
    });

    test('Today does not depend on any filter cubit at all (only on its rule)', () {
      final a = TodayRules.months(since: since, today: '2026-11-01');
      final b = TodayRules.months(since: since, today: '2026-11-01');
      expect(a, b);
      expect(a, ['2026-10', '2026-11']);
    });
  });

  group('(b) Dashboard and Guests keep their own month', () {
    test('changing the Dashboard month never moves the admin Guests month, and the other way round', () async {
      final dashboard = DashboardCubit(_Team());
      final adminGuests = GuestsFilterCubit(month: '2026-09');
      await dashboard.load('2026-10');
      expect(adminGuests.state.month, '2026-09');
      await dashboard.load('2026-08');
      expect(adminGuests.state.month, '2026-09');
      adminGuests.selectMonth('2026-11');
      expect(dashboard.state.month, '2026-08');
      await dashboard.close();
      await adminGuests.close();
    });

    test('each Guests screen has its own selection (HOD tab and a worker\'s guests screen)', () async {
      final tab = GuestsFilterCubit(month: '2026-10');
      final workerScreen = GuestsFilterCubit(month: '2026-10');
      tab.selectChip('call');
      workerScreen.selectMonth('2026-07');
      expect(tab.state, const GuestsFilter(month: '2026-10', chip: 'call'));
      expect(workerScreen.state, const GuestsFilter(month: '2026-07'));
      await tab.close();
      await workerScreen.close();
    });

    test('a Dashboard tile opens Guests on that month and chip only when tapped', () async {
      final adminGuests = GuestsFilterCubit(month: '2026-09');
      adminGuests.show(month: '2026-10', chip: 'call');
      expect(adminGuests.state, const GuestsFilter(month: '2026-10', chip: 'call'));
      await adminGuests.close();
    });

    test('the guest cache has no selected month to share', () async {
      final bloc = GuestsBloc(guestRepository: _LiveByMonth());
      bloc.add(const WatchMonthsEvent(['2026-08']));
      bloc.add(const WatchMonthsEvent(['2026-10']));
      await tick();
      expect(bloc.state.months.keys.toSet(), {'2026-08', '2026-10'});
      await bloc.close();
    });
  });

  group('(c) sign-out or a new account never shows the previous person\'s guests', () {
    test('reset stops every live listener and empties the cache', () async {
      final repo = _LiveByMonth();
      final bloc = GuestsBloc(guestRepository: repo);
      bloc.add(const WatchMonthsEvent(['2026-10', '2026-11']));
      await tick();
      repo.of('2026-10').add([guest('A1', '2026-10-28', days: 4)]);
      await tick();
      bloc.add(const ResetGuestsEvent());
      await tick();
      expect(bloc.state.months, isEmpty);
      expect(bloc.liveMonths, isEmpty);
      expect(repo.cancelled, 2);
      // A late update from the old listener is ignored.
      repo.of('2026-10').add([guest('A2', '2026-10-28')]);
      await tick();
      expect(bloc.state.months, isEmpty);
      // The next person subscribes afresh.
      bloc.add(const WatchMonthsEvent(['2026-10']));
      await tick();
      expect(bloc.liveMonths, {'2026-10'});
      await bloc.close();
    });

    test('Apps Script source: a fetch that ends after a reset is dropped', () async {
      final repo = _Fetching()..data['2026-10'] = [guest('A1', '2026-10-28')];
      final bloc = GuestsBloc(guestRepository: repo);
      bloc.add(const WatchMonthsEvent(['2026-10']));
      bloc.add(const ResetGuestsEvent());
      await tick();
      await tick();
      expect(bloc.state.guestsOf('2026-10'), isEmpty);
      await bloc.close();
    });
  });

  group('Apps Script source', () {
    test('fetches per month, refreshes and keeps the device copy when offline', () async {
      final repo = _Fetching()
        ..data['2026-10'] = [guest('G1', '2026-10-28')]
        ..cached['2026-11'] = [guest('C1', '2026-11-01')];
      final bloc = GuestsBloc(guestRepository: repo);
      bloc.add(const WatchMonthsEvent(['2026-10']));
      await tick();
      expect(bloc.state.guestsOf('2026-10').single.id, 'G1');

      repo.fail = true;
      bloc.add(const WatchMonthsEvent(['2026-11']));
      await tick();
      expect(bloc.state.guestsOf('2026-11').single.id, 'C1');
      expect(bloc.state.fromCacheIn(['2026-11']), isTrue);

      repo.fail = false;
      repo.data['2026-10'] = [guest('G1', '2026-10-28'), guest('G2', '2026-10-30')];
      bloc.add(const RefreshMonthsEvent(['2026-10']));
      await tick();
      expect(bloc.state.guestsOf('2026-10').length, 2);
      await bloc.close();
    });

    test('nothing cached and offline: a plain failure for that month only', () async {
      final repo = _Fetching()..fail = true;
      final bloc = GuestsBloc(guestRepository: repo);
      bloc.add(const WatchMonthsEvent(['2026-10']));
      await tick();
      expect(bloc.state.failureFor(['2026-10']), 'Offline');
      expect(bloc.state.failureFor(['2026-11']), isNull);
      await bloc.close();
    });
  });

  group('Today rule', () {
    test('new (within 3 days) and outstanding (over 3 days), not called yet', () {
      final view = TodayRules.of([
        guest('N0', '2026-11-01', days: 0),
        guest('N3', '2026-10-29', days: 3),
        guest('O4', '2026-10-28', days: 4),
        guest('O9', '2026-10-28', days: 9),
        guest('called', '2026-10-30', calls: 1, days: 2),
        guest('member', '2026-10-28', days: 4, status: 'Member'),
        guest('notInterested', '2026-10-28', days: 4, status: 'Not interested'),
        guest('beforeGoLive', '2026-10-20', days: 12),
        guest('noDate', '2026-11-01', days: 0).copyWithoutDate(),
      ], since: since);
      expect(view.outstanding.map((g) => g.id), ['O9', 'O4']);
      expect(view.fresh.map((g) => g.id), ['N3', 'N0']);
      expect(view.next!.id, 'O9');
      expect(view.total, 4);
    });

    test('months cover go-live to now, across a year end, at most 6', () {
      expect(TodayRules.months(since: '2026-10-28', today: '2026-10-30'), ['2026-10']);
      expect(TodayRules.months(since: '2026-10-28', today: '2027-01-02'), ['2026-10', '2026-11', '2026-12', '2027-01']);
      expect(TodayRules.months(since: '2026-10-28', today: '2027-12-01').length, 6);
    });
  });
}

extension on GuestEntity {
  GuestEntity copyWithoutDate() => GuestEntity(
        id: id,
        name: name,
        phone: phone,
        status: status,
        daysSinceVisit: daysSinceVisit,
        callCount: callCount,
        sundayAttendance: sundayAttendance,
        wednesdayAttendance: wednesdayAttendance,
        teamJoined: teamJoined,
        lastFeedback: lastFeedback,
        lastFeedbackDate: lastFeedbackDate,
        followUpCount: followUpCount,
        month: month,
      );
}
