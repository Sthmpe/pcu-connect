import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/errors/failures.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/firestore/nudge_repository.dart';
import 'package:workflow/domain/attention_rules.dart';
import 'package:workflow/domain/nudge.dart';
import 'package:workflow/presentation/admin/widgets/needs_attention_card.dart';
import 'package:workflow/presentation/admin/widgets/nudge_sheet.dart';

class FakeNudges implements INudgeRepository {
  final sent = <(String, int, String)>[];
  ApiResult<NudgeResult> answer =
      const ApiResult.success(NudgeResult(inApp: true, pushSent: 0, emailSent: true));

  @override
  Future<ApiResult<NudgeResult>> send({required String workerEmail, required int outstanding, String personalLine = ''}) async {
    sent.add((workerEmail, outstanding, personalLine));
    return answer;
  }

  @override
  Stream<Map<String, DateTime>> recent() => Stream.value(const {});
}

const david = WorkerAttention(workerName: 'David Olanite', workerEmail: 'david@x.com', outstanding: 4, oldestDays: 9, oldestMonth: '2026-10');

Widget app(Widget child) => ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => GetMaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  group('Wording', () {
    test('the default body, with 1 guest read correctly', () {
      expect(Nudge.title, 'A gentle nudge from your HOD');
      expect(Nudge.body(4), 'You have 4 guests waiting for a call. A quick call today makes a big difference. We are cheering you on.');
      expect(Nudge.body(1), startsWith('You have 1 guest waiting'));
    });

    test('the result says how it went out, push or not', () {
      expect(const NudgeResult(inApp: true, pushSent: 0, emailSent: true).summary('David'), 'David will see it in the app and by email.');
      expect(const NudgeResult(inApp: true, pushSent: 2, emailSent: true).summary('David'),
          'David will see it in the app, on their phone and by email.');
      expect(const NudgeResult(inApp: true, pushSent: 0, emailSent: false).summary('David'), 'David will see it in the app.');
    });

    test('nudged in the last 24 hours, in Lagos time', () {
      // 09:42 UTC is 10:42 in Lagos; Sunday 1 November 2026.
      expect(nudgedLine(DateTime.utc(2026, 11, 1, 9, 42)), 'Nudged at 10:42. You can nudge again at 10:42 on Monday.');
    });

    test('the latest nudge per worker', () {
      final m = NudgeRepository.fromDocs([
        {'worker': 'david@x.com', 'sentAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 8))},
        {'worker': 'david@x.com', 'sentAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 9))},
        {'worker': 'ada@x.com', 'sentAt': DateTime.utc(2026, 11, 1, 7)},
        {'worker': '', 'sentAt': DateTime.utc(2026, 11, 1, 7)},
      ]);
      expect(m.keys.toSet(), {'david@x.com', 'ada@x.com'});
      expect(m['david@x.com']!.isAtSameMomentAs(DateTime.utc(2026, 11, 1, 9)), isTrue);
    });
  });

  group('The sheet', () {
    testWidgets('previews the nudge and sends it with the personal line', (tester) async {
      final repo = FakeNudges();
      var closed = 0;
      await tester.pumpWidget(app(NudgeSheet(worker: david, repo: repo, onSent: () => closed++)));
      expect(find.text('Nudge David'), findsOneWidget);
      expect(find.text('A gentle nudge from your HOD'), findsOneWidget);
      expect(find.text(Nudge.body(4)), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Proud of you!');
      await tester.ensureVisible(find.text('Send nudge'));
      await tester.tap(find.text('Send nudge'));
      await tester.pump();
      expect(repo.sent, [('david@x.com', 4, 'Proud of you!')]);
      expect(closed, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('too soon: the server says so and the sheet stays open', (tester) async {
      final repo = FakeNudges()..answer = const ApiResult.failure(ServerFailure('David was nudged in the last 24 hours.', 'TOO_SOON'));
      var closed = 0;
      await tester.pumpWidget(app(NudgeSheet(worker: david, repo: repo, onSent: () => closed++)));
      await tester.ensureVisible(find.text('Send nudge'));
      await tester.tap(find.text('Send nudge'));
      await tester.pump();
      expect(closed, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('David was nudged in the last 24 hours.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });

  group('The row', () {
    testWidgets('a Nudge button until nudged, then when they can be nudged again', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(NeedsAttentionRow(worker: david, onNudge: () => taps++)));
      await tester.tap(find.text('Nudge'));
      expect(taps, 1);
      await tester.pumpWidget(app(NeedsAttentionRow(worker: david, nudgedAt: DateTime.utc(2026, 11, 1, 9, 42), onNudge: () => taps++)));
      expect(find.text('Nudge'), findsNothing);
      expect(find.textContaining('Nudged at 10:42'), findsOneWidget);
    });
  });
}
