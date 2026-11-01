import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/utils/month_utils.dart';
import 'package:workflow/core/widgets/app_controls.dart';
import 'package:workflow/data/firestore/firestore_guest_repository.dart';
import 'package:workflow/domain/entities/worker_user.dart';
import 'package:workflow/domain/repositories/i_auth_repository.dart';

class _Auth implements IAuthRepository {
  @override
  final WorkerUser? currentUser;
  _Auth(this.currentUser);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const david = WorkerUser(id: 'W005', name: 'David Olanite', email: 'david@x.com', phone: '', role: 'Worker', active: true);
const boss = WorkerUser(id: 'W001', name: 'Boss', email: 'boss@x.com', phone: '', role: 'Admin', active: true);

void main() {
  test('All months labels', () {
    expect(MonthUtils.label(MonthUtils.all), 'All months');
    expect(MonthUtils.short(MonthUtils.all), 'All months');
    expect(MonthUtils.name(MonthUtils.all), 'All months');
    expect(MonthUtils.isCurrent(MonthUtils.all), isFalse);
  });

  test('a worker on All months gets every guest assigned to them, from every month, and nobody else\'s', () async {
    final db = FakeFirebaseFirestore();
    Future<void> add(String id, String month, String to) =>
        db.collection('guests').doc(id).set({'name': id, 'month': month, 'serviceDate': '$month-05', 'assignedTo': to});
    await add('Sep', '2026-09', 'david@x.com');
    await add('Oct', '2026-10', 'david@x.com');
    await add('Nov', '2026-11', 'david@x.com');
    await add('Ada', '2026-10', 'ada@x.com');
    await add('Free', '2026-10', '');
    final mine = await FirestoreGuestRepository(db: db, authRepository: _Auth(david)).watchGuests(month: MonthUtils.all)!.first;
    expect(mine.map((g) => g.id).toSet(), {'Sep', 'Oct', 'Nov'});
    // Never the whole collection, even for an admin.
    final admin = await FirestoreGuestRepository(db: db, authRepository: _Auth(boss)).watchGuests(month: MonthUtils.all)!.first;
    expect(admin, isEmpty);
  });

  testWidgets('the worker month picker offers All months first', (tester) async {
    String? picked;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(
        home: Scaffold(body: Center(child: MonthPill(month: '2026-10', allowAll: true, onChanged: (m) => picked = m))),
      ),
    ));
    await tester.tap(find.byType(MonthPill));
    await tester.pumpAndSettle();
    expect(find.text('All months'), findsOneWidget);
    await tester.tap(find.text('All months'));
    await tester.pumpAndSettle();
    expect(picked, MonthUtils.all);
  });

  testWidgets('the HOD month picker has no All months', (tester) async {
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(home: Scaffold(body: Center(child: MonthPill(month: '2026-10', onChanged: (_) {})))),
    ));
    await tester.tap(find.byType(MonthPill));
    await tester.pumpAndSettle();
    expect(find.text('All months'), findsNothing);
  });
}
