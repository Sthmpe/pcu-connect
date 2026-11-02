import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_colors.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/domain/attention_rules.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/presentation/admin/widgets/needs_attention_card.dart';

const since = '2026-10-28';

GuestEntity g(String id, String worker, String visit, {int calls = 0}) => GuestEntity(
      id: id,
      name: 'Guest $id',
      phone: '',
      status: calls == 0 ? 'New guest' : 'Contacted',
      daysSinceVisit: 0,
      serviceDate: visit,
      callCount: calls,
      sundayAttendance: 0,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: calls,
      month: visit.substring(0, 7),
      assignedWorkerName: worker,
    );

void main() {
  final guests = [
    g('1', 'David Olanite', '2026-10-28'), // 9 days on 6 Nov
    g('2', 'David Olanite', '2026-11-01'), // 5 days
    g('3', 'David Olanite', '2026-11-02'), // 4 days
    g('4', 'David Olanite', '2026-11-01'), // 5 days
    g('5', 'David Olanite', '2026-11-04'), // 2 days: still New
    g('6', 'David Olanite', '2026-10-29', calls: 1), // called
    g('7', 'Ada Bello', '2026-11-01'), // 5 days
    g('8', 'Tunde Ade', '2026-11-05'), // New
    g('9', '', '2026-10-28'), // not assigned
    g('10', 'Ada Bello', '2026-10-20'), // before go-live
  ];

  test('workers with outstanding guests, the longest wait first', () {
    final list = AttentionRules.build(guests: guests, since: since, today: '2026-11-06');
    expect(list.map((w) => w.line), ['David, 4 outstanding, oldest 9 days', 'Ada, 1 outstanding, oldest 5 days']);
    expect(list.first.oldestMonth, '2026-10');
    expect(list.first.urgent, isTrue, reason: '9 days is past ATTENTION_AFTER_DAYS (7)');
    expect(list.last.urgent, isFalse);
  });

  test('no outstanding guests, no card', () {
    expect(AttentionRules.build(guests: [g('8', 'Tunde Ade', '2026-11-05')], since: since, today: '2026-11-06'), isEmpty);
  });

  test('counts by worker name for the Team screen', () {
    final counts = AttentionRules.counts(AttentionRules.build(guests: guests, since: since, today: '2026-11-06'));
    expect(counts, {'david olanite': 4, 'ada bello': 1});
  });

  testWidgets('a row is red when urgent', (tester) async {
    final w = AttentionRules.build(guests: guests, since: since, today: '2026-11-06').first;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(home: Scaffold(body: NeedsAttentionRow(worker: w))),
    ));
    final text = tester.widget<Text>(find.text('David, 4 outstanding, oldest 9 days'));
    expect(text.style?.color, AppColors.redInk);
    expect(w.items.length, 4);
    expect(AttentionRules.total(AttentionRules.build(guests: guests, since: since, today: '2026-11-06')), 5);
  });
}
