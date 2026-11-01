import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/domain/membership_progress.dart';
import 'package:workflow/presentation/worker/screens/guest_detail_screen.dart';

// November 2026: Sundays 1, 8, 15, 22, 29; Wednesdays 4, 11, 18, 25.
MembershipProgress of(String today, {List<String> sun = const [], List<String> wed = const [], String status = 'Returning'}) =>
    MembershipProgress.of(today: today, sundayDates: sun, wednesdayDates: wed, status: status);

void main() {
  group('The calendar', () {
    test('this month\'s Sundays and Wednesdays, filled when attended', () {
      final p = of('2026-11-12', sun: ['2026-11-01', '2026-11-08', '2026-10-25'], wed: ['2026-11-04']);
      expect(p.sundays.map((d) => d.dayOfMonth), [1, 8, 15, 22, 29]);
      expect(p.wednesdaysInMonth.map((d) => d.dayOfMonth), [4, 11, 18, 25]);
      expect(p.sundays.where((d) => d.attended).map((d) => d.dayOfMonth), [1, 8]);
      expect(p.wednesdaysInMonth.where((d) => d.attended).map((d) => d.dayOfMonth), [4]);
      expect(p.sundaysAttended, 2, reason: 'October does not count in November');
      expect(p.wednesdaysAttended, 1);
      expect(p.sundays.where((d) => d.past).map((d) => d.dayOfMonth), [1, 8]);
    });

    test('February 2026 has four of each', () {
      final p = of('2026-02-01');
      expect(p.sundays.map((d) => d.dayOfMonth), [1, 8, 15, 22]);
      expect(p.wednesdaysInMonth.map((d) => d.dayOfMonth), [4, 11, 18, 25]);
    });
  });

  group('The line', () {
    test('nothing yet: 4 more Sundays', () {
      expect(of('2026-11-01').line, '4 more Sundays to become a member');
    });

    test('3 Sundays: 1 more Sunday', () {
      expect(of('2026-11-16', sun: ['2026-11-01', '2026-11-08', '2026-11-15']).line, '1 more Sunday to become a member');
    });

    test('2 Sundays and 2 Wednesdays: 1 more Sunday', () {
      expect(of('2026-11-12', sun: ['2026-11-01', '2026-11-08'], wed: ['2026-11-04', '2026-11-11']).line,
          '1 more Sunday to become a member');
    });

    test('3 Sundays and 1 Wednesday: either way', () {
      expect(of('2026-11-16', sun: ['2026-11-01', '2026-11-08', '2026-11-15'], wed: ['2026-11-04']).line,
          '1 more Sunday, or 1 more Wednesday to become a member');
    });

    test('2 Sundays and 1 Wednesday: both ways named', () {
      expect(of('2026-11-12', sun: ['2026-11-01', '2026-11-08'], wed: ['2026-11-04']).line,
          '2 more Sundays, or 1 more Sunday and 1 more Wednesday to become a member');
    });

    test('only the possible way is offered when Wednesdays have run out', () {
      // After Wednesday 25 November: no Wednesdays left, one Sunday (29th) left.
      expect(of('2026-11-26', sun: ['2026-11-01', '2026-11-08', '2026-11-15'], wed: ['2026-11-04']).line,
          '1 more Sunday to become a member');
    });

    test('not enough services left this month', () {
      expect(of('2026-11-26', sun: ['2026-11-01']).line,
          'Not enough services left this month. The count starts again on 1 December.');
      expect(of('2026-12-28').line, 'Not enough services left this month. The count starts again on 1 January.');
    });

    test('a service today still counts as ahead', () {
      // Sunday 29 November, not attended yet.
      expect(of('2026-11-29', sun: ['2026-11-01', '2026-11-08', '2026-11-15']).line, '1 more Sunday to become a member');
    });

    test('rule met this month, or already a member', () {
      expect(of('2026-11-23', sun: ['2026-11-01', '2026-11-08', '2026-11-15', '2026-11-22']).line,
          'Has met the membership rule this month.');
      expect(of('2026-11-12', sun: ['2026-11-01', '2026-11-08', '2026-11-15'], wed: ['2026-11-04', '2026-11-11']).line,
          'Has met the membership rule this month.');
      expect(of('2026-11-12', status: 'Member').line, 'Became a member. Thank you for walking with them.');
    });
  });

  testWidgets('a dot is filled navy when attended and says so to screen readers', (tester) async {
    final p = of('2026-11-12', sun: ['2026-11-08']);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, __) => MaterialApp(home: Scaffold(body: MembershipDots(label: 'Sun', days: p.sundays))),
    ));
    expect(find.text('8'), findsOneWidget);
    expect(find.bySemanticsLabel('Sunday 8 November, attended'), findsOneWidget);
    expect(find.bySemanticsLabel('Sunday 15 November, not attended'), findsOneWidget);
  });
}
