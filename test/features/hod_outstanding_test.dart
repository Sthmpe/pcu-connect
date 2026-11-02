import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/core/widgets/app_controls.dart';
import 'package:workflow/core/widgets/app_surfaces.dart';
import 'package:workflow/core/widgets/attention.dart';
import 'package:workflow/data/firestore/nudge_repository.dart';
import 'package:workflow/domain/attention_rules.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/entities/team_member.dart';
import 'package:workflow/domain/nudge.dart';
import 'package:workflow/domain/repositories/i_guest_repository.dart';
import 'package:workflow/domain/repositories/i_team_repository.dart';
import 'package:workflow/presentation/admin/screens/hod_outstanding_screen.dart';
import 'package:workflow/presentation/common/insights_cubits.dart';
import 'package:workflow/presentation/guests/bloc/guests_bloc.dart';

class _Guests implements IGuestRepository {
  final List<GuestEntity> all;
  _Guests(this.all);
  @override
  Stream<List<GuestEntity>>? watchGuests({required String month}) => Stream.value(all.where((g) => g.month == month).toList());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Team implements ITeamRepository {
  @override
  Future<ApiResult<List<TeamMember>>> fetchTeam({required String month}) async => const ApiResult.success([
        TeamMember(id: 'W005', name: 'David Olanite', email: 'david@x.com', role: 'Worker', active: true, phone: ''),
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Nudges implements INudgeRepository {
  final logged = <String>[];
  @override
  Stream<NudgeHistory> history() => Stream.value(NudgeHistory.empty);
  @override
  Future<void> logWhatsApp({required String workerEmail, required String workerName, required int outstanding}) async =>
      logged.add(workerEmail);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GuestEntity g(String id, String visit) => GuestEntity(
      id: id, name: 'Guest $id', phone: '', status: 'New guest', daysSinceVisit: 0, serviceDate: visit, callCount: 0,
      sundayAttendance: 0, wednesdayAttendance: 0, teamJoined: '', lastFeedback: '', lastFeedbackDate: '',
      followUpCount: 0, month: visit.substring(0, 7), assignedWorkerName: 'David Olanite', assignedEmail: 'david@x.com',
    );

void main() {
  setUp(() => Get.testMode = true);

  testWidgets('a worker row: count, oldest wait, a pulsing mark, and Not nudged yet', (tester) async {
    const w = WorkerAttention(workerName: 'David Olanite', workerEmail: 'david@x.com', outstanding: 4, oldestDays: 9, oldestMonth: '2026-10');
    var opened = 0;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(home: Scaffold(body: HodWorkerRow(worker: w, onTap: () => opened++))),
    ));
    expect(find.text('David, 4 outstanding, oldest 9 days'), findsOneWidget);
    expect(find.text('Not nudged yet'), findsOneWidget);
    expect(find.byType(PulseDot), findsOneWidget);
    await tester.tap(find.byType(HodWorkerRow));
    expect(opened, 1);
  });

  testWidgets("one worker's outstanding guests with Nudge, WhatsApp and Redistribute; no phone is said plainly", (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Guests visited at least 4 days ago, after go-live: outstanding today.
    final old = DateTime.now().subtract(const Duration(days: 5));
    final day = '${old.year}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}';
    final bloc = GuestsBloc(guestRepository: _Guests([g('A', day), g('B', day)]));
    final team = TeamCubit(_Team());
    final nudges = _Nudges();
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MultiRepositoryProvider(
        providers: [RepositoryProvider<INudgeRepository>.value(value: nudges)],
        child: MultiBlocProvider(
          providers: [BlocProvider.value(value: bloc), BlocProvider.value(value: team)],
          child: const GetMaterialApp(home: WorkerOutstandingScreen(worker: 'david@x.com')),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text("David's outstanding"), findsOneWidget);
    expect(find.text('Guest A'), findsOneWidget);
    expect(find.text('Guest B'), findsOneWidget);
    expect(find.text('Nudge'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Redistribute'), findsOneWidget);
    // Room between the buttons and from the card's edges.
    final nudge = tester.getRect(find.ancestor(of: find.text('Nudge'), matching: find.byType(AppButton)));
    final wa = tester.getRect(find.ancestor(of: find.text('WhatsApp'), matching: find.byType(AppButton)));
    final card = tester.getRect(find.ancestor(of: find.text('Nudge'), matching: find.byType(AppCard)));
    expect(wa.left - nudge.right, greaterThanOrEqualTo(12));
    expect(nudge.left - card.left, greaterThanOrEqualTo(16));
    expect(card.right - wa.right, greaterThanOrEqualTo(16));
    // Redistribute: small, compact and red, with a 44px touch target.
    final redistribute = find.ancestor(of: find.text('Redistribute'), matching: find.byType(AppButton));
    expect(tester.widget<AppButton>(redistribute).compact, isTrue);
    expect(tester.widget<AppButton>(redistribute).variant, AppButtonVariant.danger);
    expect(tester.getSize(find.descendant(of: redistribute, matching: find.byType(Material)).first).height, 36);
    expect(tester.getSize(redistribute).height, 44);
    expect(tester.getSize(redistribute).width, lessThan(nudge.width * 2));
    await tester.tap(find.text('WhatsApp'));
    await tester.pump();
    expect(nudges.logged, isEmpty, reason: 'no phone saved: nothing opened, nothing logged');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('No phone saved'), findsOneWidget);
    // The pulsing dots never settle (by design): pump past the snackbar instead.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(bloc.close);
    await tester.runAsync(team.close);
  });
}
