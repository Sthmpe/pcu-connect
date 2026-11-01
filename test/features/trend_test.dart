import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/firestore/trend_repository.dart';
import 'package:workflow/presentation/admin/widgets/trend_card.dart';

class _Repo implements ITrendRepository {
  List<String>? asked;
  final List<MonthCount> data;
  _Repo(this.data);

  @override
  Future<ApiResult<List<MonthCount>>> load(List<String> months) async {
    asked = months;
    return ApiResult.success(data);
  }
}

void main() {
  test('counts guests and members of each month from Firestore', () async {
    final db = FakeFirebaseFirestore();
    Future<void> add(String id, String month, String status) =>
        db.collection('guests').doc(id).set({'month': month, 'membershipStatus': status});
    await add('a', '2026-09', 'Member');
    await add('b', '2026-09', 'Returning');
    await add('c', '2026-10', 'New guest');
    await add('d', '2026-10', 'Member');
    await add('e', '2026-10', 'Member');
    final r = await FirestoreTrendRepository(db).load(['2026-08', '2026-09', '2026-10']);
    expect(r.data!.map((m) => [m.month, m.guests, m.members]), [
      ['2026-08', 0, 0],
      ['2026-09', 2, 1],
      ['2026-10', 3, 2],
    ]);
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

  testWidgets('the card asks for the last twelve months, oldest first, with a key and month letters', (tester) async {
    final data = [for (var i = 1; i <= 12; i++) MonthCount('2026-${i.toString().padLeft(2, '0')}', i * 3, i)];
    final repo = _Repo(data);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepositoryProvider<ITrendRepository>.value(value: repo, child: const TrendCard()),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(repo.asked!.length, 12);
    expect(repo.asked!.first.compareTo(repo.asked!.last) < 0, isTrue);
    expect(find.text('Last 12 months'), findsOneWidget);
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('J'), findsNWidgets(3));
    expect(find.bySemanticsLabel(RegExp('December: 36 guests, 12 members')), findsOneWidget);
  });

  testWidgets('nothing without a trend source (Apps Script mode)', (tester) async {
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => const MaterialApp(home: Scaffold(body: TrendCard())),
    ));
    expect(find.text('Last 12 months'), findsNothing);
  });
}
