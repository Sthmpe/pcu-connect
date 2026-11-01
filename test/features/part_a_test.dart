import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/core/utils/month_utils.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/repositories/i_guest_repository.dart';
import 'package:workflow/presentation/guests/bloc/guests_bloc.dart';
import 'package:workflow/presentation/guests/bloc/guests_event.dart';
import 'package:workflow/presentation/guests/bloc/guests_filter_cubit.dart';
import 'package:workflow/presentation/worker/bloc/today_cubit.dart';
import 'package:workflow/presentation/worker/screens/worker_shell_screen.dart';

GuestEntity g(String id, String visit) => GuestEntity(
      id: id, name: id, phone: '', status: 'New guest', daysSinceVisit: 0, serviceDate: visit, callCount: 0,
      sundayAttendance: 0, wednesdayAttendance: 0, teamJoined: '', lastFeedback: '', lastFeedbackDate: '',
      followUpCount: 0, month: visit.substring(0, 7),
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

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('the worker Guests screen opens on All months', () {
    expect(WorkerShellScreen.guestsDefaultMonth, MonthUtils.all);
    expect(GuestsFilterCubit(month: WorkerShellScreen.guestsDefaultMonth).state.month, 'all');
  });

  test('Today ignores the Guests month: All months or a single month changes nothing on Today', () async {
    final repo = _Live();
    final bloc = GuestsBloc(guestRepository: repo);
    final today = TodayCubit(guests: bloc, worker: () => 'd@x.com', since: '2026-10-28', clock: () => DateTime.utc(2026, 11, 8, 9))
      ..start();
    await tick();
    repo.of('2026-10').add([g('old', '2026-10-28')]);
    repo.of('2026-11').add([g('new', '2026-11-07')]);
    await tick();
    final before = today.state.view.all.map((i) => '${i.guest.id}:${i.section}').toList();
    expect(today.state.view.outstanding.single.guest.id, 'old');

    // The Guests screen asks for All months, then for September.
    bloc.add(const WatchMonthsEvent([MonthUtils.all]));
    await tick();
    repo.of(MonthUtils.all).add([g('old', '2026-10-28'), g('new', '2026-11-07')]);
    bloc.add(const WatchMonthsEvent(['2026-09']));
    await tick();
    repo.of('2026-09').add([g('sep', '2026-09-20')]);
    await tick();
    expect(today.state.view.all.map((i) => '${i.guest.id}:${i.section}').toList(), before);
    await today.close();
    await bloc.close();
  });
}
