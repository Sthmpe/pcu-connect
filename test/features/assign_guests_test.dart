import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/repositories/assign_repository.dart';
import 'package:workflow/presentation/admin/widgets/assign_guests_sheet.dart';

class FakeAssign implements IAssignRepository {
  int waiting;
  final asked = <(String, String)>[];
  int assigns = 0;
  FakeAssign(this.waiting);

  @override
  Future<ApiResult<AssignPreview>> preview({required String from, required String to}) async {
    asked.add((from, to));
    return ApiResult.success(AssignPreview(unassigned: waiting, workers: 3));
  }

  @override
  Future<ApiResult<AssignResult>> assign({required String from, required String to}) async {
    assigns++;
    final n = waiting;
    waiting = 0;
    return ApiResult.success(AssignResult(assigned: n, summary: n == 0 ? '' : '$n guests assigned: David 2, Worker A 1'));
  }
}

Widget app(Widget child) => ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => GetMaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  setUp(() => Get.testMode = true);

  test('the result line', () {
    expect(assignedLine(3), 'Assigned 3 guests');
    expect(assignedLine(1), 'Assigned 1 guest');
    expect(assignedLine(0), 'No guests were assigned');
  });

  testWidgets('defaults to go-live to today, counts, confirms, assigns, then shows none left', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAssign(3);
    await tester.pumpWidget(app(AssignGuestsSheet(repo: repo, today: '2026-11-08')));
    await tester.pump();
    expect(repo.asked.first, ('2026-10-28', '2026-11-08'));
    expect(find.text('Wed 28 Oct'), findsOneWidget);
    expect(find.text('Sun 8 Nov'), findsOneWidget);
    expect(find.text('3 guests have no worker in these dates.'), findsOneWidget);

    await tester.tap(find.text('Assign 3 guests'));
    await tester.pumpAndSettle();
    expect(find.text('Assign 3 guests?'), findsOneWidget);
    await tester.tap(find.text('Assign').last);
    await tester.pumpAndSettle();
    expect(repo.assigns, 1);
    expect(find.text('Every guest in these dates has a worker.'), findsOneWidget);
    // Nothing left: the button cannot assign again.
    await tester.tap(find.text('Assign guests').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.assigns, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the dashboard card shows only while guests are waiting', (tester) async {
    await tester.pumpWidget(app(UnassignedCard(repo: FakeAssign(4), today: '2026-11-08')));
    await tester.pump();
    expect(find.text('4 guests are waiting for a worker'), findsOneWidget);
    await tester.pumpWidget(app(UnassignedCard(key: const ValueKey('none'), repo: FakeAssign(0), today: '2026-11-08')));
    await tester.pump();
    expect(find.textContaining('waiting for a worker'), findsNothing);
  });
}
