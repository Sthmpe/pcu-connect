import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/widgets/app_display.dart';
import 'package:workflow/core/widgets/attention.dart';
import 'package:workflow/core/widgets/guest_row.dart';
import 'package:workflow/core/widgets/status_tone.dart';
import 'package:workflow/domain/attention_rules.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/presentation/admin/screens/hod_outstanding_screen.dart';

const guest = GuestEntity(
  id: 'G1', name: 'Ada Obi', phone: '0803', status: 'New guest', daysSinceVisit: 5, serviceDate: '2026-10-28',
  callCount: 0, sundayAttendance: 0, wednesdayAttendance: 0, teamJoined: '', lastFeedback: '', lastFeedbackDate: '',
  followUpCount: 0, month: '2026-10',
);

Widget app(Widget child) => ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );

void main() {
  setUp(() {});

  testWidgets('an outstanding guest row has exactly one dot of its own: the one before "Waiting N days"', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(GuestRow(
      guest: guest,
      outstanding: true,
      line: 'Waiting 5 days for a call',
      pill: 'Outstanding',
      pillTone: StatusTone.red,
      onTap: () {},
    )));
    expect(find.byType(PulseDot), findsOneWidget);
    // The only other dot is the red pill's own, which stays as it is.
    expect(find.byType(StatusDot), findsOneWidget);
    expect(find.descendant(of: find.byType(AppPill), matching: find.byType(StatusDot)), findsOneWidget);
    // Nothing on the initial: the dot sits in the same row as the waiting text, before it.
    final row = find.ancestor(of: find.text('Waiting 5 days for a call'), matching: find.byType(Row)).first;
    expect(find.descendant(of: row, matching: find.byType(PulseDot)), findsOneWidget);
    expect(tester.getCenter(find.byType(PulseDot)).dx, lessThan(tester.getTopLeft(find.text('Waiting 5 days for a call')).dx));
    expect(find.descendant(of: find.byType(AppAvatar), matching: find.byType(PulseDot)), findsNothing);
  });

  testWidgets('a guest who is not outstanding keeps its plain status dot and no pulse', (tester) async {
    await tester.pumpWidget(app(GuestRow(guest: guest, line: 'Visited 2 days ago', onTap: () {})));
    expect(find.byType(PulseDot), findsNothing);
    expect(find.byType(StatusDot), findsOneWidget);
  });

  testWidgets("the HOD's worker row: one dot, before the text, none on the initial", (tester) async {
    const w = WorkerAttention(workerName: 'David Olanite', workerEmail: 'd@x.com', outstanding: 4, oldestDays: 9, oldestMonth: '2026-10');
    await tester.pumpWidget(app(HodWorkerRow(worker: w, onTap: () {})));
    expect(find.byType(PulseDot), findsOneWidget);
    expect(find.descendant(of: find.byType(AppAvatar), matching: find.byType(PulseDot)), findsNothing);
    expect(tester.getCenter(find.byType(PulseDot)).dx,
        lessThan(tester.getTopLeft(find.text('David, 4 outstanding, oldest 9 days')).dx));
  });

  testWidgets('the pulsing dot takes no more room than a plain dot', (tester) async {
    await tester.pumpWidget(app(const Center(child: PulseDot())));
    expect(tester.getSize(find.byType(PulseDot)), const Size(8, 8));
  });
}
