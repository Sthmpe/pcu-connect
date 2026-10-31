import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/core/utils/lagos_time.dart';
import 'package:workflow/data/firestore/firestore_mappers.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/repositories/i_guest_repository.dart';
import 'package:workflow/presentation/guests/bloc/guests_bloc.dart';
import 'package:workflow/presentation/guests/bloc/guests_event.dart';
import 'package:workflow/presentation/guests/bloc/guests_state.dart';

/// Live repository double: tests push lists into [controller].
class _LiveRepo implements IGuestRepository {
  final controller = StreamController<List<GuestEntity>>.broadcast();
  final watched = <String>[];

  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) {
    watched.add(month);
    return controller.stream;
  }

  @override
  Future<ApiResult<List<GuestEntity>>> fetchGuests({String? month, String? filter}) async =>
      const ApiResult.success([]);

  @override
  List<GuestEntity>? getCachedGuests({String? month}) => null;

  @override
  Future<ApiResult<GuestEntity>> fetchGuestDetail(String guestId) => throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();
}

GuestEntity _guest(String id, String month) => FirestoreMappers.guest(id, {
      'name': 'Guest $id',
      'month': month,
      'assignedTo': 'david@x.com',
      'assignedName': 'David Olanite',
      'followUpCount': 0,
    });

void main() {
  group('LagosTime', () {
    test('day boundary uses Lagos, not UTC', () {
      // 23:30 UTC on 31 Oct is already 1 Nov in Lagos.
      final late = DateTime.utc(2026, 10, 31, 23, 30);
      expect(LagosTime.day(late), '2026-11-01');
      expect(LagosTime.today(late), '2026-11-01');
      expect(LagosTime.month(late), '2026-11');
    });

    test('days between calendar dates', () {
      expect(LagosTime.daysBetween('2026-10-28', '2026-10-31'), 3);
      expect(LagosTime.daysBetween('2026-10-31', '2026-11-01'), 1);
      expect(LagosTime.daysBetween('bad', '2026-11-01'), 0);
    });
  });

  group('FirestoreMappers', () {
    final clock = DateTime.utc(2026, 10, 31, 12);

    test('guest document becomes a GuestEntity', () {
      final g = FirestoreMappers.guest(
        'G1',
        {
          'name': 'Ada Obi',
          'phone': '0803 555 0101',
          'serviceDate': '2026-10-25',
          'month': '2026-10',
          'assignedTo': 'david@x.com',
          'assignedName': 'David Olanite',
          'membershipStatus': 'Returning',
          'followUpCount': 2,
          'teamJoined': 'Workforce',
          'lastFeedback': 'Lovely chat',
          'lastFeedbackDate': DateTime.utc(2026, 10, 28, 23, 30),
          'sundayDates': ['2026-09-28', '2026-10-25', '2026-10-26'],
          'wednesdayDates': ['2026-10-29'],
        },
        clock: clock,
      );
      expect(g.daysSinceVisit, 6);
      expect(g.callCount, 2);
      expect(g.status, 'Returning');
      expect(g.sundayAttendance, 2, reason: 'only this month counts');
      expect(g.wednesdayAttendance, 1);
      expect(g.assignedWorkerName, 'David Olanite');
      expect(g.lastFeedbackDate, '29 Oct', reason: 'shown in Lagos time');
      expect(g.urgency, GuestUrgency.green);
    });

    test('missing fields fall back safely', () {
      final g = FirestoreMappers.guest('G2', {}, clock: clock);
      expect(g.name, 'Guest');
      expect(g.status, 'New guest');
      expect(g.callCount, 0);
      expect(g.daysSinceVisit, 0);
    });

    test('follow-up logged by an admin keeps the worker and gets the label', () {
      final f = FirestoreMappers.followUp(
        'F1',
        {
          'worker': 'david@x.com',
          'loggedBy': 'boss@x.com',
          'callDate': '2026-10-30',
          'outcome': 'Reached',
          'attendedSunday': true,
        },
        workerNames: {'david@x.com': 'David Olanite'},
      );
      expect(f.workerName, 'David Olanite');
      expect(f.loggedByAdmin, isTrue);
      expect(f.attendedSunday, isTrue);
    });

    test('a worker\'s own follow-up has no label', () {
      final f = FirestoreMappers.followUp('F2', {'worker': 'david@x.com', 'loggedBy': 'david@x.com'});
      expect(f.loggedByAdmin, isFalse);
      final legacy = FirestoreMappers.followUp('F3', {'worker': 'david@x.com'});
      expect(legacy.loggedByAdmin, isFalse, reason: 'rows from before Logged by existed');
    });

    test('user document maps the role', () {
      expect(FirestoreMappers.user('boss@x.com', {'role': 'admin', 'active': true}).isAdmin, isTrue);
      final w = FirestoreMappers.user('d@x.com', {'name': 'D', 'role': 'worker', 'active': false});
      expect(w.isAdmin, isFalse);
      expect(w.active, isFalse);
    });
  });

  group('GuestsBloc with a live source', () {
    test('lists update on their own and keep the chosen filter', () async {
      final repo = _LiveRepo();
      final bloc = GuestsBloc(guestRepository: repo);
      bloc.add(const LoadGuestsEvent(month: '2026-10'));
      await Future<void>.delayed(Duration.zero);
      repo.controller.add([_guest('G1', '2026-10')]);
      await Future<void>.delayed(Duration.zero);
      expect((bloc.state as GuestsLoadedState).allGuests.length, 1);

      bloc.add(const ChangeChipFilterEvent('call'));
      await Future<void>.delayed(Duration.zero);
      // A new guest is assigned, or one is reassigned away: the list just changes.
      repo.controller.add([_guest('G1', '2026-10'), _guest('G2', '2026-10')]);
      await Future<void>.delayed(Duration.zero);
      final s = bloc.state as GuestsLoadedState;
      expect(s.allGuests.length, 2);
      expect(s.chipFilter, 'call', reason: 'filter kept across live updates');

      repo.controller.add([_guest('G2', '2026-10')]);
      await Future<void>.delayed(Duration.zero);
      expect((bloc.state as GuestsLoadedState).allGuests.map((g) => g.id), ['G2']);
      await bloc.close();
    });

    test('a stream error shows a plain message', () async {
      final repo = _LiveRepo();
      final bloc = GuestsBloc(guestRepository: repo);
      bloc.add(const LoadGuestsEvent(month: '2026-10'));
      await Future<void>.delayed(Duration.zero);
      repo.controller.addError(Exception('permission-denied'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<GuestsFailureState>());
      expect((bloc.state as GuestsFailureState).message, 'We could not load your guests. Try again.');
      await bloc.close();
    });

    test('changing month subscribes to that month', () async {
      final repo = _LiveRepo();
      final bloc = GuestsBloc(guestRepository: repo);
      bloc.add(const LoadGuestsEvent(month: '2026-10'));
      await Future<void>.delayed(Duration.zero);
      repo.controller.add([_guest('G1', '2026-10')]);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SelectMonthEvent('2026-09'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.watched.last, '2026-09');
      await bloc.close();
    });
  });
}
