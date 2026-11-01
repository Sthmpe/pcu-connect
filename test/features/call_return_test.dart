import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/utils/call_return_watcher.dart';
import 'package:workflow/core/widgets/app_controls.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/presentation/worker/widgets/call_outcome_sheet.dart';

const guest = GuestEntity(
  id: 'g1',
  name: 'Ada Obi',
  phone: '08031234567',
  status: 'New guest',
  daysSinceVisit: 0,
  serviceDate: '2026-10-28',
  callCount: 0,
  sundayAttendance: 0,
  wednesdayAttendance: 0,
  teamJoined: '',
  lastFeedback: '',
  lastFeedbackDate: '',
  followUpCount: 0,
  month: '2026-10',
);

void main() {
  group('CallReturnWatcher', () {
    late DateTime now;
    late CallReturnWatcher watcher;
    late List<String> asked;

    setUp(() {
      now = DateTime.utc(2026, 11, 1, 10);
      watcher = CallReturnWatcher(clock: () => now);
      asked = [];
      watcher.returns.listen(asked.add);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('leaving for the call and coming back asks once', () async {
      watcher.launched('g1');
      watcher.onLifecycle(AppLifecycleState.inactive);
      watcher.onLifecycle(AppLifecycleState.hidden);
      watcher.onLifecycle(AppLifecycleState.paused);
      watcher.onLifecycle(AppLifecycleState.hidden);
      watcher.onLifecycle(AppLifecycleState.inactive);
      watcher.onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(asked, ['g1']);

      // Leaving and coming back again without a new tap asks nothing.
      watcher.onLifecycle(AppLifecycleState.hidden);
      watcher.onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(asked, ['g1']);
    });

    test('not leaving the app never asks', () async {
      watcher.launched('g1');
      // A confirm dialog takes focus, the worker cancels.
      watcher.onLifecycle(AppLifecycleState.inactive);
      watcher.onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(asked, isEmpty);
    });

    test('a link that could not open never asks, even after a later leave', () async {
      watcher.launched('g1');
      watcher.cancel();
      watcher.onLifecycle(AppLifecycleState.hidden);
      watcher.onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(asked, isEmpty);
    });

    test('an old tap is forgotten: leaving much later does not ask', () async {
      watcher.launched('g1');
      now = now.add(const Duration(minutes: 5));
      watcher.onLifecycle(AppLifecycleState.hidden);
      watcher.onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(asked, isEmpty);
    });

    test('a newer tap replaces the older guest', () async {
      watcher.launched('g1');
      watcher.launched('g2');
      watcher.onLifecycle(AppLifecycleState.paused);
      watcher.onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(asked, ['g2']);
    });
  });

  group('CallOutcomeSheet', () {
    Future<void> pump(WidgetTester tester, Widget sheet) => tester.pumpWidget(ScreenUtilInit(
          designSize: AppSizes.designSize,
          builder: (_, __) => GetMaterialApp(home: Scaffold(body: sheet)),
        ));

    testWidgets('shows the four quick outcomes; Save waits for a choice, then saves it', (tester) async {
      final saved = <String>[];
      await pump(
        tester,
        CallOutcomeSheet(
          guest: guest,
          onSave: (o) async {
            saved.add(o);
            return true;
          },
          onFullForm: (_) {},
        ),
      );
      expect(find.text('How did the call go?'), findsOneWidget);
      expect(find.text('With Ada Obi'), findsOneWidget);
      for (final o in ['Reached', 'No answer', 'Switched off', 'Not interested']) {
        expect(find.text(o), findsOneWidget);
      }

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved, isEmpty);

      await tester.tap(find.text('No answer'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved, ['No answer']);

      // A second tap while saving does not save twice.
      await tester.tap(find.byType(AppButton).first, warnIfMissed: false);
      await tester.pump();
      expect(saved, ['No answer']);
    });

    testWidgets('a failed save lets the worker try again', (tester) async {
      var tries = 0;
      await pump(
        tester,
        CallOutcomeSheet(
          guest: guest,
          onSave: (_) async {
            tries++;
            return false;
          },
          onFullForm: (_) {},
        ),
      );
      await tester.tap(find.text('Reached'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(tries, 2);
    });

    testWidgets('the full form gets the outcome picked so far', (tester) async {
      final opened = <String?>[];
      await pump(
        tester,
        CallOutcomeSheet(guest: guest, onSave: (_) async => true, onFullForm: opened.add),
      );
      await tester.tap(find.text('Open the full form'));
      await tester.pump();
      await tester.tap(find.text('Switched off'));
      await tester.pump();
      await tester.tap(find.text('Open the full form'));
      await tester.pump();
      expect(opened, [null, 'Switched off']);
    });
  });
}
