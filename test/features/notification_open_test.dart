import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/errors/failures.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/domain/entities/app_notification.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/repositories/i_guest_repository.dart';
import 'package:workflow/presentation/common/notifications_screen.dart';
import 'package:workflow/presentation/guests/bloc/guests_bloc.dart';
import 'package:workflow/presentation/worker/screens/guest_detail_screen.dart';

const september = GuestEntity(
  id: 'G9',
  name: 'Seun Ade',
  phone: '08031112222',
  status: 'Contacted',
  daysSinceVisit: 40,
  serviceDate: '2026-09-20',
  callCount: 1,
  sundayAttendance: 0,
  wednesdayAttendance: 0,
  teamJoined: '',
  lastFeedback: '',
  lastFeedbackDate: '',
  followUpCount: 1,
  month: '2026-09',
);

class _Repo implements IGuestRepository {
  final watched = <String>[];
  final bool missing;
  _Repo({this.missing = false});

  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) {
    watched.add(month);
    return Stream.value(month == '2026-09' ? [september] : const []);
  }

  @override
  Future<ApiResult<GuestEntity>> fetchGuestDetail(String guestId) async => missing
      ? const ApiResult.failure(ServerFailure('We could not find this guest.'))
      : const ApiResult.success(september);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppNotification note(String id, DateTime? at) => AppNotification(id: id, title: id, body: '', createdAt: at);

void main() {
  group('Today and Earlier', () {
    // 1 November 2026, 10:00 in Lagos.
    final clock = DateTime.utc(2026, 11, 1, 9);

    test('split by the Lagos day, newest order kept', () {
      final items = [
        note('pending', null),
        note('this morning', DateTime.utc(2026, 11, 1, 7)),
        // 23:30 UTC on 31 October is already 1 November in Lagos.
        note('just after midnight Lagos', DateTime.utc(2026, 10, 31, 23, 30)),
        note('late yesterday', DateTime.utc(2026, 10, 31, 22, 30)),
        note('last week', DateTime.utc(2026, 10, 25, 12)),
      ];
      final (today, earlier) = groupNotifications(items, clock);
      expect(today.map((n) => n.id), ['pending', 'this morning', 'just after midnight Lagos']);
      expect(earlier.map((n) => n.id), ['late yesterday', 'last week']);
    });

    test('a group can be empty', () {
      final (today, earlier) = groupNotifications([note('old', DateTime.utc(2026, 10, 1))], clock);
      expect(today, isEmpty);
      expect(earlier.single.id, 'old');
    });
  });

  group('Opening a guest whose month is not on screen', () {
    Future<GuestsBloc> pump(WidgetTester tester, _Repo repo) async {
      final bloc = GuestsBloc(guestRepository: repo);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: AppSizes.designSize,
        builder: (_, __) => RepositoryProvider<IGuestRepository>.value(
          value: repo,
          child: BlocProvider.value(
            value: bloc,
            child: const GetMaterialApp(home: GuestDetailScreen(guestId: 'G9')),
          ),
        ),
      ));
      return bloc;
    }

    testWidgets('loads the guest by ID, then keeps their month live', (tester) async {
      final repo = _Repo();
      final bloc = await pump(tester, repo);
      await tester.pump();
      await tester.pump();
      expect(find.text('Seun Ade'), findsOneWidget);
      expect(repo.watched, ['2026-09']);
      expect(bloc.state.find('G9'), isNotNull);
      await tester.runAsync(bloc.close);
    });

    testWidgets('says so when the guest cannot be found', (tester) async {
      final bloc = await pump(tester, _Repo(missing: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('We could not find this guest.'), findsOneWidget);
      await tester.runAsync(bloc.close);
    });
  });
}
