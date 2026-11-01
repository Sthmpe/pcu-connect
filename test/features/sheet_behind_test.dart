import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/firestore/sheet_sync_repository.dart';
import 'package:workflow/domain/entities/sheet_sync.dart';
import 'package:workflow/presentation/admin/bloc/sheet_sync_cubit.dart';
import 'package:workflow/presentation/admin/screens/admin_dashboard_tab.dart';

class _Repo implements ISheetSyncRepository {
  final statuses = StreamController<SheetSyncStatus>.broadcast();
  int calls = 0;

  @override
  Stream<SheetSyncStatus> watch() => statuses.stream;

  @override
  Future<ApiResult<SheetSyncResult>> syncNow() async {
    calls++;
    return const ApiResult.success(SheetSyncResult(followUps: 1, guests: 1));
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 2, 12);

  test('the sync result says what was synced', () {
    expect(const SheetSyncResult(followUps: 6, guests: 4, followUpGuests: 4).message, 'Synced 6 follow-ups for 4 guests');
    expect(const SheetSyncResult(followUps: 1, guests: 1, followUpGuests: 1).message, 'Synced 1 follow-up for 1 guest');
    expect(const SheetSyncResult(followUps: 0, guests: 0).message, 'The sheet is up to date.');
    expect(const SheetSyncResult(followUps: 0, guests: 3).message, 'Synced 3 guests');
    expect(const SheetSyncResult(followUps: 2, guests: 2).message, 'Synced 2 follow-ups', reason: 'an older backend without the guest count');
  });

  test('the sheet link comes from meta/sync', () {
    expect(SheetSyncRepository.fromDoc({'sheetUrl': 'https://docs.google.com/spreadsheets/d/X/edit'}).sheetUrl,
        'https://docs.google.com/spreadsheets/d/X/edit');
    expect(SheetSyncRepository.fromDoc({}).sheetUrl, '');
  });

  testWidgets('Open the sheet shows once the address is known', (tester) async {
    final repo = _Repo();
    final cubit = SheetSyncCubit(repo);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(home: Scaffold(body: BlocProvider.value(value: cubit, child: const SheetSyncCard()))),
    ));
    expect(find.text('Open the sheet'), findsNothing);
    repo.statuses.add(SheetSyncStatus(lastSyncedAt: now, sheetUrl: 'https://docs.google.com/spreadsheets/d/X/edit'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Open the sheet'), findsOneWidget);
    unawaited(cubit.close());
  });

  test('a day or more behind', () {
    expect(SheetSyncStatus(lastSyncedAt: now.subtract(const Duration(hours: 23))).behind(now), isNull);
    expect(SheetSyncStatus(lastSyncedAt: now.subtract(const Duration(hours: 24))).behind(now), 'Sheet is a day behind. Sync now.');
    expect(SheetSyncStatus(lastSyncedAt: now.subtract(const Duration(hours: 50))).behind(now), 'Sheet is 2 days behind. Sync now.');
    expect(const SheetSyncStatus().behind(now), isNull, reason: 'never synced is said by the Sheet card');
  });

  testWidgets('the banner shows when behind, and Sync now syncs', (tester) async {
    final repo = _Repo();
    final cubit = SheetSyncCubit(repo);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MaterialApp(
        home: Scaffold(body: BlocProvider.value(value: cubit, child: SheetBehindBanner(clock: now))),
      ),
    ));
    expect(find.textContaining('behind'), findsNothing);

    repo.statuses.add(SheetSyncStatus(lastSyncedAt: now.subtract(const Duration(hours: 30))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Sheet is a day behind. Sync now.'), findsOneWidget);
    await tester.tap(find.text('Sync now'));
    await tester.pump();
    expect(repo.calls, 1);

    repo.statuses.add(SheetSyncStatus(lastSyncedAt: now));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('behind'), findsNothing);
    unawaited(cubit.close());
  });
}
