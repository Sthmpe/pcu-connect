import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/firestore/notifications_repository.dart';
import 'package:workflow/data/firestore/worker_calls_repository.dart';
import 'package:workflow/domain/entities/app_notification.dart';
import 'package:workflow/domain/entities/follow_up_entry.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/repositories/i_guest_repository.dart';
import 'package:workflow/domain/today_rules.dart';
import 'package:workflow/presentation/common/notifications_cubit.dart';
import 'package:workflow/presentation/guests/bloc/guests_bloc.dart';
import 'package:workflow/presentation/guests/bloc/guests_event.dart';
import 'package:workflow/presentation/guests/bloc/guests_state.dart';
import 'package:workflow/presentation/worker/bloc/today_cubit.dart';

const g1 = GuestEntity(
  id: 'G1', name: 'Ada', phone: '', status: 'New guest', daysSinceVisit: 0, serviceDate: '2026-10-28',
  callCount: 0, sundayAttendance: 0, wednesdayAttendance: 0, teamJoined: '', lastFeedback: '', lastFeedbackDate: '',
  followUpCount: 0, month: '2026-10', gender: 'Female', sundayDates: ['2026-11-01'], memberSince: '2026-11-01',
  assignedEmail: 'd@x.com', lastOutcome: 'No answer', lastCallDate: '2026-10-30',
);

class _Live implements IGuestRepository {
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
  var c = StreamController<List<CallRecord>>.broadcast();
  int watches = 0;
  @override
  Stream<List<CallRecord>>? watch() {
    watches++;
    return c.stream;
  }
}

class _Bell implements INotificationsRepository {
  var c = StreamController<List<AppNotification>>.broadcast();
  int watches = 0;
  @override
  Stream<List<AppNotification>> watch() {
    watches++;
    return c.stream;
  }

  @override
  Future<void> markAllRead() async {}
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('a failed guest read is a failure with a message, never an empty list', () async {
    final repo = _Live();
    final bloc = GuestsBloc(guestRepository: repo);
    bloc.add(const WatchMonthsEvent(['2026-10']));
    await tick();
    repo.of('2026-10').addError(Exception('permission-denied'));
    await tick();
    await tick();
    expect(bloc.state.of('2026-10')!.status, MonthStatus.failed);
    expect(bloc.state.failureFor(['2026-10']), 'We could not load your guests. Try again.');
    // Try again listens afresh.
    bloc.add(const WatchMonthsEvent(['2026-10']));
    await tick();
    repo.of('2026-10').add([g1]);
    await tick();
    expect(bloc.state.guestsOf('2026-10').single.id, 'G1');
    await bloc.close();
  });

  test('Today: a failed calls read says so, and Try again reads them again', () async {
    final repo = _Live();
    final calls = _Calls();
    final bloc = GuestsBloc(guestRepository: repo);
    final cubit = TodayCubit(guests: bloc, calls: calls, worker: () => 'd@x.com', since: '2026-10-28',
        clock: () => DateTime.utc(2026, 11, 2, 9))
      ..start();
    await tick();
    repo.of('2026-10').add([g1]);
    repo.of('2026-11').add(const []);
    calls.c.addError(Exception('unavailable'));
    await tick();
    await tick();
    expect(cubit.state.failure, 'We could not load your calls. Try again.');
    cubit.retry();
    await tick();
    expect(calls.watches, 2);
    calls.c.add(const []);
    await tick();
    expect(cubit.state.failure, isNull);
    expect(cubit.state.view.total, 1);
    await cubit.close();
    await bloc.close();
  });

  test('the bell: a failed read is marked failed, and Try again listens again', () async {
    final repo = _Bell();
    final cubit = NotificationsCubit(repo)..start();
    repo.c.addError(Exception('denied'));
    await tick();
    expect(cubit.state.failed, isTrue);
    cubit.retry();
    repo.c.add(const []);
    await tick();
    expect(cubit.state.failed, isFalse);
    expect(cubit.state.loaded, isTrue);
    expect(repo.watches, 2);
    await cubit.close();
  });

  test('a guest opened by ID keeps every field with its history', () {
    final h = g1.withHistory(const [
      FollowUpEntry(id: 'F1', date: '1 Nov', outcome: 'Reached', note: '', attendedSunday: false, attendedWednesday: false, team: '', workerName: 'David', loggedByName: '', loggedByAdmin: false),
    ]);
    expect([h.gender, h.sundayDates, h.memberSince, h.assignedEmail, h.lastOutcome, h.lastCallDate, h.serviceDate],
        [g1.gender, g1.sundayDates, g1.memberSince, g1.assignedEmail, g1.lastOutcome, g1.lastCallDate, g1.serviceDate]);
    expect(h.history.single.id, 'F1');
  });
}
