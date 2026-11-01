import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/repositories/redistribute_repository.dart';
import 'package:workflow/presentation/admin/widgets/redistribute_sheet.dart';

const people = [
  RedistributeShare(email: 'a@x.com', name: 'Worker A', count: 0),
  RedistributeShare(email: 'b@x.com', name: 'Worker B', count: 0),
];
const waiting = [
  RedistributeCandidate(id: 'G1', name: 'Ada Obi', serviceDate: '2026-10-28'),
  RedistributeCandidate(id: 'G2', name: 'Tunde Bello', serviceDate: '2026-10-29'),
];

class FakeRedistribute implements IRedistributeRepository {
  final previews = <(RedistributeMode, List<String>, List<String>?)>[];
  final runs = <(RedistributeMode, List<String>?)>[];

  RedistributePlan _plan(RedistributeMode mode, List<String> ids, List<String>? to, {bool moved = false}) {
    final n = mode == RedistributeMode.selected ? ids.length : (mode == RedistributeMode.outstanding ? 2 : 2);
    final names = (to ?? ['a@x.com', 'b@x.com']).map((e) => e == 'a@x.com' ? 'Worker A' : 'Worker B').toList();
    final text = n == 0 ? 'No guests to move.' : '$n guests: ${names.map((x) => '$x ${n ~/ names.length}').join(', ')}';
    return RedistributePlan(guests: n, moved: moved ? n : 0, text: text, shares: people, candidates: waiting);
  }

  @override
  Future<ApiResult<RedistributePlan>> preview(
      {required String fromEmail, required RedistributeMode mode, List<String> guestIds = const [], List<String>? toEmails}) async {
    previews.add((mode, guestIds, toEmails));
    return ApiResult.success(_plan(mode, guestIds, toEmails));
  }

  @override
  Future<ApiResult<RedistributePlan>> run(
      {required String fromEmail, required RedistributeMode mode, List<String> guestIds = const [], List<String>? toEmails}) async {
    runs.add((mode, toEmails));
    return ApiResult.success(_plan(mode, guestIds, toEmails, moved: true));
  }
}

void main() {
  setUp(() => Get.testMode = true);

  test('the result line', () {
    expect(movedLine(12), 'Moved 12 guests');
    expect(movedLine(1), 'Moved 1 guest');
    expect(movedLine(0), 'No guests were moved');
  });

  testWidgets('outstanding by default, everyone receives, preview then confirm then the same counts', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRedistribute();
    var moved = 0;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => GetMaterialApp(
        home: Scaffold(
          body: RedistributeSheet(repo: repo, workerEmail: 'd@x.com', workerName: 'David Olanite', onMoved: () => moved++),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("Redistribute David's guests"), findsOneWidget);
    expect(repo.previews.last.$1, RedistributeMode.outstanding);
    expect(repo.previews.last.$3, isNull, reason: 'spread evenly among every active worker');
    expect(find.text('2 guests: Worker A 1, Worker B 1'), findsOneWidget);

    // Untick Worker B: only Worker A receives.
    await tester.tap(find.text('Worker B'));
    await tester.pumpAndSettle();
    expect(repo.previews.last.$3, ['a@x.com']);
    expect(find.text('2 guests: Worker A 2'), findsOneWidget);

    await tester.tap(find.text('Redistribute 2 guests'));
    await tester.pumpAndSettle();
    expect(find.text('Move 2 guests?'), findsOneWidget);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(repo.runs.single.$1, RedistributeMode.outstanding);
    expect(repo.runs.single.$2, ['a@x.com']);
    expect(moved, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Selected lists the guests never called and moves only the ticked ones', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRedistribute();
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => GetMaterialApp(
        home: Scaffold(
          body: RedistributeSheet(repo: repo, workerEmail: 'd@x.com', workerName: 'David Olanite', onMoved: () {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Obi'), findsOneWidget);
    expect(find.text('Redistribute'), findsOneWidget, reason: 'nothing ticked yet');
    await tester.tap(find.text('Tunde Bello'));
    await tester.pumpAndSettle();
    expect(repo.previews.last.$1, RedistributeMode.selected);
    expect(repo.previews.last.$2, ['G2']);
    expect(find.text('Redistribute 1 guest'), findsOneWidget);
  });
}
