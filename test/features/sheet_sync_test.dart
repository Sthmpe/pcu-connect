import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/errors/failures.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/data/firestore/sheet_sync_repository.dart';
import 'package:workflow/domain/entities/sheet_sync.dart';
import 'package:workflow/presentation/admin/bloc/sheet_sync_cubit.dart';

class _Repo implements ISheetSyncRepository {
  final statuses = StreamController<SheetSyncStatus>.broadcast();
  ApiResult<SheetSyncResult> next = const ApiResult.success(SheetSyncResult(followUps: 3, guests: 42, followUpGuests: 2));
  final gate = Completer<void>();
  int calls = 0;

  @override
  Stream<SheetSyncStatus> watch() => statuses.stream;

  @override
  Future<ApiResult<SheetSyncResult>> syncNow() async {
    calls++;
    await gate.future;
    return next;
  }
}

// 1 Nov 2026, 10:00 in Lagos.
final clock = DateTime.utc(2026, 11, 1, 9);

void main() {
  group('Last synced line (Lagos time)', () {
    test('today, yesterday, older, never', () {
      expect(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 10, 31, 23, 5)).line(clock), 'Last synced: today 12:05 AM');
      expect(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 10, 31, 20, 40)).line(clock), 'Last synced: yesterday 9:40 PM');
      expect(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 10, 28, 8, 15)).line(clock), 'Last synced: 28 Oct, 9:15 AM');
      expect(const SheetSyncStatus().line(clock), 'Not synced to the sheet yet');
    });
    test('gentle warning when more than a day behind, or when the last run failed', () {
      expect(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 10, 31, 23, 5)).warning(clock), isNull);
      expect(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 10, 31, 8)).warning(clock), 'Sheet is a day behind. Sync now.');
      expect(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 10, 28, 8)).warning(clock), 'Sheet is 4 days behind. Sync now.');
      expect(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 11, 1, 8), lastOk: false).warning(clock),
          'The last sync did not finish. Try again.');
    });
    test('result messages', () {
      expect(const SheetSyncResult(followUps: 50, guests: 42, followUpGuests: 40).message, 'Synced 50 follow-ups for 40 guests');
      expect(const SheetSyncResult(followUps: 1, guests: 1, followUpGuests: 1).message, 'Synced 1 follow-up for 1 guest');
      expect(const SheetSyncResult(followUps: 0, guests: 1).message, 'Synced 1 guest');
      expect(const SheetSyncResult(followUps: 2, guests: 0).message, 'Synced 2 follow-ups');
      expect(const SheetSyncResult(followUps: 0, guests: 0).message, 'The sheet is up to date.');
    });
    test('meta/sync document', () {
      final s = SheetSyncRepository.fromDoc({
        'lastSheetSyncAt': DateTime.utc(2026, 11, 1, 8),
        'running': false,
        'lastResult': {'ok': false, 'error': 'Firestore read failed (503)'},
      });
      expect(s.lastOk, isFalse);
      expect(s.lastError, contains('503'));
      expect(SheetSyncRepository.fromDoc(null), const SheetSyncStatus());
      expect(SheetSyncRepository.fromDoc({'running': true}).running, isTrue);
    });
  });

  group('SheetSyncCubit', () {
    test('Syncing... then "Synced 3 follow-ups for 2 guests", and the dashboard is refreshed', () async {
      final repo = _Repo();
      var refreshed = 0;
      final cubit = SheetSyncCubit(repo, onSynced: () => refreshed++);
      final done = cubit.syncNow();
      expect(cubit.state.syncing, isTrue);
      expect(cubit.state.busy, isTrue);
      await cubit.syncNow(); // a second tap while busy does nothing
      expect(repo.calls, 1);
      repo.gate.complete();
      await done;
      expect(cubit.state.syncing, isFalse);
      expect(cubit.state.message, 'Synced 3 follow-ups for 2 guests');
      expect(cubit.state.messageIsError, isFalse);
      expect(refreshed, 1);
      await cubit.close();
    });

    test('a sync already running shows a plain message', () async {
      final repo = _Repo()
        ..next = const ApiResult.failure(ServerFailure('A sync is already running. Try again in a minute.', 'BUSY'));
      final cubit = SheetSyncCubit(repo);
      repo.gate.complete();
      await cubit.syncNow();
      expect(cubit.state.message, 'A sync is already running. Try again in a minute.');
      expect(cubit.state.messageIsError, isTrue);
      await cubit.close();
    });

    test('a nightly run in progress on the server disables the button; the line updates live', () async {
      final repo = _Repo();
      final cubit = SheetSyncCubit(repo);
      repo.statuses.add(const SheetSyncStatus(running: true));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.busy, isTrue);
      await cubit.syncNow();
      expect(repo.calls, 0);
      repo.statuses.add(SheetSyncStatus(lastSyncedAt: DateTime.utc(2026, 11, 1, 8)));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.status.lastSyncedAt, DateTime.utc(2026, 11, 1, 8));
      await cubit.close();
    });
  });
}
