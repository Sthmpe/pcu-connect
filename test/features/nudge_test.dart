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
import 'package:workflow/core/utils/phone_intl.dart';
import 'package:workflow/domain/message_templates.dart';

class FakeNudges implements INudgeRepository {
  final sent = <(String, int, String)>[];
  ApiResult<NudgeResult> answer =
      const ApiResult.success(NudgeResult(inApp: true, pushSent: 0, emailSent: true));

  @override
  Future<ApiResult<NudgeResult>> send({required String workerEmail, required int outstanding, String personalLine = ''}) async {
    sent.add((workerEmail, outstanding, personalLine));
    return answer;
  }

  NudgeHistory past = NudgeHistory.empty;
  final whatsApp = <(String, int)>[];

  @override
  Stream<NudgeHistory> history() => Stream.value(past);

  @override
  Future<void> logWhatsApp({required String workerEmail, required String workerName, required int outstanding}) async =>
      whatsApp.add((workerEmail, outstanding));
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

    test('history: last nudge on any channel; the 24 hours count only the friendly nudge', () {
      final h = NudgeRepository.fromDocs([
        {'worker': 'david@x.com', 'sentAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 8)), 'channel': 'app'},
        {'worker': 'david@x.com', 'sentAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 9)), 'channel': 'whatsapp'},
        {'worker': 'ada@x.com', 'sentAt': DateTime.utc(2026, 11, 1, 7), 'channel': 'whatsapp'},
        {'worker': '', 'sentAt': DateTime.utc(2026, 11, 1, 7)},
      ]);
      final now = DateTime.utc(2026, 11, 1, 12);
      expect(h.last('david@x.com')!.isWhatsApp, isTrue);
      expect(h.last('david@x.com')!.at.isAtSameMomentAs(DateTime.utc(2026, 11, 1, 9)), isTrue);
      expect(h.friendlyWithin24h('david@x.com', now)!.isAtSameMomentAs(DateTime.utc(2026, 11, 1, 8)), isTrue);
      expect(h.friendlyWithin24h('ada@x.com', now), isNull, reason: 'a WhatsApp nudge does not use up the 24 hours');
      expect(h.friendlyWithin24h('david@x.com', DateTime.utc(2026, 11, 2, 9)), isNull);
      expect(lastNudgedLine(h.last('ada@x.com')!, now), 'Last nudged 5 h ago on WhatsApp');
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
    testWidgets('a Nudge button, and when they were last nudged', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(NeedsAttentionRow(worker: david, onNudge: () => taps++)));
      await tester.tap(find.text('Nudge'));
      expect(taps, 1);
      await tester.pumpWidget(app(NeedsAttentionRow(
          worker: david,
          lastNudge: NudgeLog(worker: 'david@x.com', at: DateTime.now().subtract(const Duration(minutes: 20)), channel: 'whatsapp'),
          onNudge: () => taps++)));
      expect(find.text('Last nudged 20 min ago on WhatsApp'), findsOneWidget);
      expect(find.text('Nudge'), findsOneWidget, reason: 'WhatsApp is always possible; the sheet handles the 24 hours');
    });
  });

  group('Nudge on WhatsApp', () {
    test('Nigerian numbers in international form', () {
      expect(nigerianInternational('0803 123-4567'), '2348031234567');
      expect(nigerianInternational('+234 803 123 4567'), '2348031234567');
      expect(nigerianInternational('(0803) 123 4567'), '2348031234567');
      expect(nigerianInternational('8031234567'), '2348031234567');
      expect(nigerianInternational('002348031234567'), '2348031234567');
      expect(nigerianInternational(''), isNull);
      expect(nigerianInternational('12345'), isNull);
    });

    test('the nudge message: default wording and placeholders', () {
      final text = MessageTemplates.defaults[MessageTemplates.nudgeId]!;
      expect(text, 'Hello {worker}, you have {n} guests waiting for a call. A quick call today makes a big difference. We are cheering you on.');
      expect(MessageTemplates.fillNudge(text, workerName: 'David Olanite', waiting: 4, oldestDays: 9),
          'Hello David, you have 4 guests waiting for a call. A quick call today makes a big difference. We are cheering you on.');
      expect(MessageTemplates.fillNudge('{worker}: {n} waiting, oldest {oldest}', workerName: 'TEST Worker A', waiting: 2, oldestDays: 1),
          'Worker: 2 waiting, oldest 1 day');
    });

    testWidgets('no phone: said plainly, and the WhatsApp button is off', (tester) async {
      final repo = FakeNudges();
      await tester.pumpWidget(app(NudgeSheet(worker: david, repo: repo, onSent: () {})));
      await tester.pump();
      expect(find.text('No phone saved for David. Add one in the Workers tab.'), findsOneWidget);
      await tester.ensureVisible(find.text('Nudge on WhatsApp'));
      await tester.tap(find.text('Nudge on WhatsApp'), warnIfMissed: false);
      expect(repo.whatsApp, isEmpty);
    });

    testWidgets('within 24 hours of a friendly nudge only WhatsApp is offered', (tester) async {
      final repo = FakeNudges()
        ..past = NudgeHistory([NudgeLog(worker: 'david@x.com', at: DateTime.utc(2026, 11, 1, 9, 42), channel: 'app')]);
      await tester.pumpWidget(app(NudgeSheet(
          worker: david, repo: repo, phone: '0803 123 4567', onSent: () {}, clock: () => DateTime.utc(2026, 11, 1, 12))));
      await tester.pump();
      expect(find.text('Nudged at 10:42. You can nudge again at 10:42 on Monday.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.ensureVisible(find.text('Send nudge'));
      await tester.tap(find.text('Send nudge'), warnIfMissed: false);
      expect(repo.sent, isEmpty);
      expect(find.textContaining('Hello David, you have 4 guests'), findsOneWidget);
    });
  });
}
