import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/domain/entities/insights.dart';
import 'package:workflow/domain/insight_rules.dart';
import 'package:workflow/presentation/admin/widgets/trend_card.dart';


void main() {
  test('the Dashboard brings its own twelve months: guests and members per month, oldest first', () {
    const users = [InsightUser(email: 'd@x.com', name: 'David', isAdmin: false, active: true)];
    final guests = [
      const InsightGuest(id: 'a', serviceDate: '2026-09-07', month: '2026-09', assignedTo: 'd@x.com', status: 'Member'),
      const InsightGuest(id: 'b', serviceDate: '2026-09-14', month: '2026-09', assignedTo: 'd@x.com', status: 'Returning'),
      const InsightGuest(id: 'c', serviceDate: '2026-10-04', month: '2026-10', assignedTo: 'd@x.com', status: 'Member'),
      const InsightGuest(id: 'old', serviceDate: '2025-10-05', month: '2025-10', assignedTo: '', status: 'New guest'),
    ];
    final d = InsightRules.dashboard('2026-10', guests, const [], users);
    expect(d.trend.length, 12);
    expect(d.trend.first.month, '2025-11');
    expect(d.trend.last, const MonthCount('2026-10', 1, 1));
    expect(d.trend[d.trend.length - 2], const MonthCount('2026-09', 2, 1));
    expect(d.trend.every((m) => m.month != '2025-10'), isTrue, reason: 'thirteen months back is outside the chart');
  });

  test('the Apps Script dashboard trend is read too', () {
    final d = DashboardSummary.fromJson({
      'month': '2026-10',
      'totals': {'guests': 3},
      'topWorkers': [],
      'trend': [
        {'month': '2026-09', 'guests': 2, 'called': 1, 'members': 1},
        {'month': '2026-10', 'guests': 3, 'called': 2, 'members': 0},
      ],
    });
    expect(d.trend, const [MonthCount('2026-09', 2, 1), MonthCount('2026-10', 3, 0)]);
  });

  test('both lines share one scale; months sit in their columns', () {
    final p = TrendPainter([const MonthCount('2026-09', 10, 2), const MonthCount('2026-10', 20, 5)]);
    const size = Size(200, 108);
    expect(p.maxValue, 20);
    final top = p.pointFor(1, 20, size);
    final bottom = p.pointFor(0, 0, size);
    expect(top, const Offset(150, 4));
    expect(bottom, const Offset(50, 104));
    expect(p.pointFor(0, 10, size).dy, 54);
  });

  testWidgets('the card draws the twelve months with a key and month letters', (tester) async {
    final data = [for (var i = 1; i <= 12; i++) MonthCount('2026-${i.toString().padLeft(2, '0')}', i * 3, i)];
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TrendCard(months: data)))),
    ));
    expect(find.text('Last 12 months'), findsOneWidget);
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('J'), findsNWidgets(3));
    expect(find.bySemanticsLabel(RegExp('December: 36 guests, 12 members')), findsOneWidget);
  });

  testWidgets('nothing when there is nothing to draw', (tester) async {
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => const MaterialApp(home: Scaffold(body: TrendCard(months: []))),
    ));
    expect(find.text('Last 12 months'), findsNothing);
  });

  group('Touch and hover', () {
    final months = [for (var i = 1; i <= 12; i++) MonthCount('2026-${i.toString().padLeft(2, '0')}', i * 3, i)];
    Future<void> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: AppSizes.designSize,
        builder: (_, _) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(40), child: TrendChart(months: months)))),
      ));
    }

    test('the bubble text', () {
      expect(trendBubbleText(const MonthCount('2026-10', 116, 2)), 'October 2026\n116 guests · 2 members');
      expect(trendBubbleText(const MonthCount('2026-11', 1, 1)), 'November 2026\n1 guest · 1 member');
    });

    testWidgets('tapping a month shows its numbers; another month moves the bubble', (tester) async {
      await show(tester);
      expect(find.textContaining('guests ·'), findsNothing);
      final box = tester.getRect(find.byType(CustomPaint).last);
      final step = box.width / 12;
      await tester.tapAt(Offset(box.left + step * 9.5, box.center.dy)); // October
      await tester.pump();
      expect(find.text('October 2026\n30 guests · 10 members'), findsOneWidget);
      await tester.tapAt(Offset(box.left + step * 0.5, box.center.dy)); // January
      await tester.pump();
      expect(find.text('January 2026\n3 guests · 1 member'), findsOneWidget);
      expect(find.textContaining('October 2026'), findsNothing);
    });

    testWidgets('hovering on a computer shows the bubble, leaving hides it', (tester) async {
      await show(tester);
      final box = tester.getRect(find.byType(CustomPaint).last);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(Offset(box.left + box.width / 12 * 11.5, box.center.dy)); // December
      await tester.pump();
      expect(find.text('December 2026\n36 guests · 12 members'), findsOneWidget);
      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(find.textContaining('December 2026'), findsNothing);
    });

    testWidgets('dragging along the chart follows the finger', (tester) async {
      await show(tester);
      final box = tester.getRect(find.byType(CustomPaint).last);
      final step = box.width / 12;
      final gesture = await tester.startGesture(Offset(box.left + step * 2.5, box.center.dy));
      await gesture.moveBy(Offset(step * 1.5, 0));
      await gesture.moveBy(Offset(step * 1.5, 0));
      await tester.pump();
      expect(find.textContaining('June 2026'), findsOneWidget);
      await gesture.up();
    });
  });
}
