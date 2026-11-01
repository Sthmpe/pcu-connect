import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/firestore/worker_calls_repository.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/repositories/i_guest_repository.dart';
import 'package:workflow/domain/today_rules.dart';
import 'package:workflow/presentation/guests/bloc/guests_bloc.dart';
import 'package:workflow/presentation/guests/bloc/guests_event.dart';
import 'package:workflow/presentation/guests/bloc/guests_filter_cubit.dart';
import 'package:workflow/presentation/worker/bloc/today_cubit.dart';
import 'package:workflow/presentation/worker/screens/today_tab.dart';

const since = '2026-10-28';
const me = 'david@x.com';

GuestEntity guest(String id, String serviceDate,
        {int calls = 0, String status = 'New guest', String lastOutcome = '', String lastCallDate = ''}) =>
    GuestEntity(
      id: id,
      name: 'Guest $id',
      phone: '',
      status: status,
      daysSinceVisit: 0,
      serviceDate: serviceDate,
      callCount: calls,
      sundayAttendance: 0,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: calls,
      month: serviceDate.substring(0, 7),
      lastOutcome: lastOutcome,
      lastCallDate: lastCallDate,
    );

CallRecord call(String guestId, String day, String outcome, {String by = me, DateTime? at}) =>
    CallRecord(guestId: guestId, callDate: day, outcome: outcome, loggedBy: by, createdAt: at ?? DateTime.utc(2026, 1, 1));

TodaySection? sectionOf(TodayView v, String id) => v.itemFor(id)?.section;

TodayView build(List<GuestEntity> guests, String today, {List<CallRecord> calls = const []}) => TodayRules.build(
      guests: guests,
      since: since,
      today: today,
      calls: TodayRules.summarise(calls),
      doneToday: TodayRules.doneToday(calls, worker: me, today: today),
    );

class _LiveByMonth implements IGuestRepository {
  final streams = <String, StreamController<List<GuestEntity>>>{};
  StreamController<List<GuestEntity>> of(String m) => streams[m] ??= StreamController<List<GuestEntity>>.broadcast();
  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) => of(month).stream;
  @override
  Future<ApiResult<List<GuestEntity>>> fetchGuests({String? month, String? filter}) async => const ApiResult.success([]);
  @override
  List<GuestEntity>? getCachedGuests({String? month}) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Calls implements IWorkerCallsRepository {
  final c = StreamController<List<CallRecord>>.broadcast();
  @override
  Stream<List<CallRecord>>? watch() => c.stream;
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('New and Outstanding: day 3 vs day 4', () {
    test('3 days after the visit is New, 4 days is Outstanding', () {
      final v = build([guest('d3', '2026-10-29'), guest('d4', '2026-10-28'), guest('d0', '2026-11-01')], '2026-11-01');
      expect(sectionOf(v, 'd3'), TodaySection.fresh);
      expect(sectionOf(v, 'd0'), TodaySection.fresh);
      expect(sectionOf(v, 'd4'), TodaySection.outstanding);
      expect(v.outstanding.single.days, 4);
    });

    test('guests before go-live, and undated guests, are not on Today', () {
      final v = build([guest('old', '2026-10-27'), guest('nodate', '2026-11-01').copyWithDate('')], '2026-11-01');
      expect(v.total, 0);
    });
  });

  group('Retry', () {
    test('no answer today is not a retry yet; one day later it is', () {
      final g = [guest('r', '2026-10-28', calls: 1, status: 'New guest')];
      expect(sectionOf(build(g, '2026-11-01', calls: [call('r', '2026-11-01', 'No answer')]), 'r'), isNull);
      expect(sectionOf(build(g, '2026-11-02', calls: [call('r', '2026-11-01', 'No answer')]), 'r'), TodaySection.retry);
    });

    test('Busy and Switched off count as no answer; Wrong number and Reached do not', () {
      for (final o in ['No answer', 'Busy', 'Switched off']) {
        expect(sectionOf(build([guest('r', '2026-10-28', calls: 1)], '2026-11-03', calls: [call('r', '2026-11-01', o)]), 'r'),
            TodaySection.retry, reason: o);
      }
      for (final o in ['Wrong number', 'Reached']) {
        expect(sectionOf(build([guest('r', '2026-10-28', calls: 1, status: 'Contacted')], '2026-11-03', calls: [call('r', '2026-11-01', o)]), 'r'),
            isNull, reason: o);
      }
    });

    test('after 3 tries there is no retry (the guest becomes Unreachable and stays off Follow-up due)', () {
      final calls = [call('r', '2026-10-29', 'No answer'), call('r', '2026-10-30', 'No answer'), call('r', '2026-10-31', 'No answer')];
      expect(sectionOf(build([guest('r', '2026-10-28', calls: 3, status: 'Unreachable')], '2026-11-02', calls: calls), 'r'), isNull);
      expect(sectionOf(build([guest('r', '2026-10-28', calls: 3, status: 'Unreachable')], '2026-11-30', calls: calls), 'r'), isNull);
      final two = calls.take(2).toList();
      final item = build([guest('r', '2026-10-28', calls: 2)], '2026-11-02', calls: two).itemFor('r')!;
      expect(item.section, TodaySection.retry);
      expect(todayLine(item), 'No answer 3 days ago, call 3 of 3');
    });
  });

  group('Follow-up due', () {
    test('6 days since the last call is not due; 7 days is', () {
      final g = [guest('f', '2026-10-28', calls: 1, status: 'Contacted')];
      final calls = [call('f', '2026-10-29', 'Reached')];
      expect(sectionOf(build(g, '2026-11-04', calls: calls), 'f'), isNull);
      expect(sectionOf(build(g, '2026-11-05', calls: calls), 'f'), TodaySection.followUpDue);
      expect(todayLine(build(g, '2026-11-05', calls: calls).itemFor('f')!), 'Last call 7 days ago');
    });

    test('Member, Not interested and Unreachable are never due; Contacted and Returning are', () {
      final calls = [call('f', '2026-10-29', 'Reached')];
      for (final s in ['Member', 'Not interested', 'Unreachable']) {
        expect(sectionOf(build([guest('f', '2026-10-28', calls: 1, status: s)], '2026-11-20', calls: calls), 'f'), isNull, reason: s);
      }
      for (final s in ['Contacted', 'Returning', 'New guest']) {
        expect(sectionOf(build([guest('f', '2026-10-28', calls: 1, status: s)], '2026-11-20', calls: calls), 'f'),
            TodaySection.followUpDue, reason: s);
      }
    });
  });

  group('A call logged today takes the guest off Today, and fills the ring', () {
    test('outstanding guest called today (Reached) leaves; ring 1 of 2', () {
      final guests = [guest('o', '2026-10-28'), guest('n', '2026-11-01')];
      final before = build(guests, '2026-11-02');
      expect(before.total, 2);
      expect(ringHeadline(before), '0 of 2 calls today');
      final after = build([guest('o', '2026-10-28', calls: 1, status: 'Contacted'), guest('n', '2026-11-01')], '2026-11-02',
          calls: [call('o', '2026-11-02', 'Reached')]);
      expect(sectionOf(after, 'o'), isNull);
      expect(after.total, 1);
      expect(after.ringDone, 1);
      expect(after.ringTotal, 2);
      expect(ringHeadline(after), '1 of 2 calls today');
    });

    test('done counts distinct guests the worker logged today, not admin saves or yesterday', () {
      final calls = [
        call('a', '2026-11-02', 'No answer'),
        call('a', '2026-11-02', 'Reached'),
        call('b', '2026-11-02', 'Reached'),
        call('c', '2026-11-02', 'Reached', by: 'boss@x.com'),
        call('d', '2026-11-01', 'Reached'),
      ];
      expect(TodayRules.doneToday(calls, worker: me, today: '2026-11-02'), 2);
    });

    test('nothing due and nothing done: the ring says so', () {
      expect(ringHeadline(const TodayView()), 'No calls due today');
    });
  });

  group('Calls summary', () {
    test('latest call wins, and a save waiting to sync is the newest that day', () {
      final s = TodayRules.summarise([
        call('g', '2026-11-01', 'Reached', at: DateTime.utc(2026, 11, 1, 9)),
        CallRecord(guestId: 'g', callDate: '2026-11-01', outcome: 'No answer', loggedBy: me),
        call('g', '2026-10-30', 'Busy', at: DateTime.utc(2026, 10, 30, 9)),
      ]);
      expect(s['g']!.lastOutcome, 'No answer');
      expect(s['g']!.lastDay, '2026-11-01');
      expect(s['g']!.count, 3);
    });

    test('Apps Script source: the guest\'s own last call day and outcome are used', () {
      final v = TodayRules.build(
          guests: [guest('r', '2026-10-28', calls: 1, lastOutcome: 'No answer', lastCallDate: '2026-10-31')],
          since: since,
          today: '2026-11-01');
      expect(sectionOf(v, 'r'), TodaySection.retry);
    });
  });

  group('TodayCubit (live)', () {
    test('Lagos midnight: 22:59 UTC is still day 3 (New), 23:00 UTC is day 4 (Outstanding)', () async {
      final repo = _LiveByMonth();
      final bloc = GuestsBloc(guestRepository: repo);
      var clock = DateTime.utc(2026, 10, 31, 22, 59); // 23:59 on 31 Oct in Lagos
      final cubit = TodayCubit(guests: bloc, worker: () => me, since: since, clock: () => clock)..start();
      await tick();
      repo.of('2026-10').add([guest('g', '2026-10-28')]);
      await tick();
      expect(sectionOf(cubit.state.view, 'g'), TodaySection.fresh);
      clock = DateTime.utc(2026, 10, 31, 23, 0); // midnight in Lagos: 1 Nov
      cubit.refreshNow();
      await tick();
      repo.of('2026-11').add(const []);
      await tick();
      expect(sectionOf(cubit.state.view, 'g'), TodaySection.outstanding);
      await cubit.close();
      await bloc.close();
    });

    test('a call saved on the phone moves the guest off Today and the ring on, at once', () async {
      final repo = _LiveByMonth();
      final calls = _Calls();
      final bloc = GuestsBloc(guestRepository: repo);
      final cubit = TodayCubit(
          guests: bloc, calls: calls, worker: () => me, since: since, clock: () => DateTime.utc(2026, 11, 2, 9))
        ..start();
      await tick();
      repo.of('2026-10').add([guest('o', '2026-10-28')]);
      repo.of('2026-11').add(const []);
      calls.c.add(const []);
      await tick();
      expect(cubit.state.view.total, 1);
      expect(cubit.state.view.ringTotal, 1);
      calls.c.add([call('o', '2026-11-02', 'Reached')]);
      await tick();
      expect(cubit.state.view.total, 0);
      expect(cubit.state.view.ringDone, 1);
      expect(cubit.state.view.ringTotal, 1);
      await cubit.close();
      await bloc.close();
    });

    test('changing the Guests month filter never changes Today', () async {
      final repo = _LiveByMonth();
      final bloc = GuestsBloc(guestRepository: repo);
      final filter = GuestsFilterCubit(month: '2026-11');
      final cubit = TodayCubit(guests: bloc, worker: () => me, since: since, clock: () => DateTime.utc(2026, 11, 2, 9))..start();
      await tick();
      repo.of('2026-10').add([guest('o', '2026-10-28')]);
      repo.of('2026-11').add([guest('n', '2026-11-01')]);
      await tick();
      final before = cubit.state.view.all.map((i) => i.guest.id).toList();
      filter.selectMonth('2026-09');
      bloc.add(WatchMonthsEvent([filter.state.month]));
      await tick();
      repo.of('2026-09').add([guest('s', '2026-09-06'), guest('t', '2026-09-13')]);
      await tick();
      expect(cubit.state.view.all.map((i) => i.guest.id).toList(), before);
      expect(before, ['n', 'o']);
      await cubit.close();
      await bloc.close();
      await filter.close();
    });
  });

  test('row lines and pills', () {
    expect(todayPill(TodaySection.outstanding), 'Outstanding');
    expect(todayPill(TodaySection.retry), 'Retry');
    expect(todayPill(TodaySection.followUpDue), 'Follow-up due');
    expect(todayPill(TodaySection.fresh), isNull);
    expect(todayLine(TodayItem(guest: guest('x', '2026-10-28'), section: TodaySection.outstanding, days: 1, calls: 0)),
        'Waiting 1 day for a call');
  });
}

extension on GuestEntity {
  GuestEntity copyWithDate(String d) => GuestEntity(
        id: id,
        name: name,
        phone: phone,
        status: status,
        daysSinceVisit: daysSinceVisit,
        serviceDate: d,
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
