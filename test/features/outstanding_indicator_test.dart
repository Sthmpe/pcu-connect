import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_icons.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/widgets/app_bottom_nav.dart';
import 'package:workflow/core/widgets/attention.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/today_rules.dart';
import 'package:workflow/presentation/common/outstanding_button.dart';

GuestEntity g(String id, String visit) => GuestEntity(
      id: id, name: 'Guest $id', phone: '', status: 'New guest', daysSinceVisit: 0, serviceDate: visit, callCount: 0,
      sundayAttendance: 0, wednesdayAttendance: 0, teamJoined: '', lastFeedback: '', lastFeedbackDate: '',
      followUpCount: 0, month: visit.substring(0, 7),
    );

Widget app(Widget child, {bool reduce = false}) => ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      ),
    );

void main() {
  test('outstanding grouped by month: this month first, then newest to oldest, longest wait first', () {
    final items = TodayRules.build(
      guests: [g('a', '2026-10-28'), g('b', '2026-11-02'), g('c', '2026-11-01'), g('d', '2026-09-30')],
      since: '2026-09-01',
      today: '2026-11-08',
    ).outstanding;
    final groups = outstandingByMonth(items, currentMonth: '2026-11');
    expect(groups.map((x) => x.$1), ['2026-11', '2026-10', '2026-09']);
    expect(groups.first.$2.map((i) => i.guest.id), ['c', 'b']);
  });

  testWidgets('the red count ripples, and holds still when the device asks for less motion', (tester) async {
    await tester.pumpWidget(app(const RippleBadge(count: 4)));
    expect(find.text('4'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(app(const RippleBadge(count: 4), reduce: true));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(app(const RippleBadge(count: 0)));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the pulsing dot is a soft pulse, and still under reduced motion', (tester) async {
    await tester.pumpWidget(app(const PulseDot()));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(app(const PulseDot(), reduce: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the Guests tab shows the outstanding count and says it to screen readers', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              items: const [AppNavItem(AppIcons.today, 'Today', badge: 5), AppNavItem(AppIcons.guests, 'Guests', alert: 3)],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    ));
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Guests, 3 outstanding'), findsOneWidget);
    expect(find.bySemanticsLabel('Today, 5 to do'), findsOneWidget);
  });

  testWidgets('the button next to the month filter shows the count and opens the list', (tester) async {
    var opened = 0;
    await tester.pumpWidget(app(OutstandingButton(count: 7, onTap: () => opened++), reduce: true));
    expect(find.bySemanticsLabel('Outstanding, 7'), findsOneWidget);
    await tester.tap(find.byType(OutstandingButton));
    expect(opened, 1);
  });
}
