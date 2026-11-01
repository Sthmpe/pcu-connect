import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/presentation/admin/screens/admin_dashboard_tab.dart';
import 'package:workflow/presentation/worker/screens/ranking_tab.dart';

Widget app(Widget child) => ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('Ranking with no points yet this month offers last month', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(NoPointsYet(previousMonth: '2026-10', onPrevious: () => taps++)));
    expect(find.text('No points yet this month. The first follow-up starts the board.'), findsOneWidget);
    await tester.tap(find.text('See October'));
    expect(taps, 1);
  });

  testWidgets('Dashboard: no guests yet this month, last month one tap away', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(EmptyMonthCard(month: '2026-11', onPrevious: () => taps++)));
    expect(find.text('No guests yet in November.'), findsOneWidget);
    await tester.tap(find.text('See October'));
    expect(taps, 1);
  });
}
