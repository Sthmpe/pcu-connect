import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/sync/sync_chip.dart';
import 'package:workflow/core/sync/sync_signals.dart';
import 'package:workflow/core/sync/sync_status_cubit.dart';

const grace = Duration(milliseconds: 20);
const syncedFor = Duration(milliseconds: 60);
Future<void> wait([Duration d = Duration.zero]) => Future<void>.delayed(d);

void main() {
  late SyncSignals signals;
  late StreamController<bool> online;
  late SyncStatusCubit cubit;
  late List<SyncChipState> seen;

  SyncStatusCubit make({bool startOnline = true}) {
    final c = SyncStatusCubit(
      signals: signals,
      online: startOnline,
      onlineChanges: online.stream,
      grace: grace,
      syncedFor: syncedFor,
    );
    seen = [c.state];
    c.stream.listen(seen.add);
    return c;
  }

  setUp(() {
    signals = SyncSignals();
    online = StreamController<bool>();
  });

  tearDown(() async {
    await cubit.close();
    await online.close();
  });

  test('quiet and online: nothing shows', () async {
    cubit = make();
    await wait(syncedFor * 2);
    expect(seen, [SyncChipState.hidden]);
  });

  test('offline, then a save waits, then it syncs, then All synced briefly', () async {
    cubit = make();
    online.add(false);
    await wait();
    expect(cubit.state, SyncChipState.offline);

    final save = Completer<void>();
    signals.trackWrite(save.future);
    await wait();
    expect(cubit.state, SyncChipState.offline, reason: 'still offline');

    online.add(true);
    await wait();
    expect(cubit.state, SyncChipState.syncing);

    save.complete();
    await wait();
    expect(cubit.state, SyncChipState.synced);
    await wait(syncedFor * 2);
    expect(cubit.state, SyncChipState.hidden);
    expect(seen, [SyncChipState.hidden, SyncChipState.offline, SyncChipState.syncing, SyncChipState.synced, SyncChipState.hidden]);
  });

  test('back online with nothing to send: All synced, then hidden', () async {
    cubit = make(startOnline: false);
    expect(cubit.state, SyncChipState.offline);
    online.add(true);
    await wait();
    expect(cubit.state, SyncChipState.synced);
    await wait(syncedFor * 2);
    expect(cubit.state, SyncChipState.hidden);
  });

  test('new assignments arriving show Syncing, then All synced', () async {
    cubit = make();
    signals.listFromCache('oct', true);
    await wait(grace * 3);
    expect(cubit.state, SyncChipState.syncing);
    signals.listFromCache('oct', false);
    await wait();
    expect(cubit.state, SyncChipState.synced);
  });

  test('a check that settles within the grace time never flashes', () async {
    cubit = make();
    final quick = Completer<void>();
    signals.trackWrite(quick.future);
    quick.complete();
    await wait(grace * 3);
    expect(seen, [SyncChipState.hidden]);
  });

  test('a closed list no longer counts as arriving; a failed write still ends', () async {
    cubit = make();
    signals.listFromCache('oct', true);
    signals.listClosed('oct');
    expect(signals.receiving.value, isFalse);
    signals.trackWrite(Future<void>.error('denied'));
    await wait();
    expect(signals.pendingWrites.value, 0);
  });

  testWidgets('the chip shows the words for each state, and nothing without the cubit', (tester) async {
    Future<void> show(SyncStatusCubit? c) => tester.pumpWidget(ScreenUtilInit(
          designSize: AppSizes.designSize,
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: c == null ? const SyncChip() : BlocProvider.value(value: c, child: const SyncChip()),
            ),
          ),
        ));
    cubit = make(startOnline: false);
    await show(cubit);
    expect(find.text('Offline, saves will sync'), findsOneWidget);
    await show(null);
    expect(find.byType(Text), findsNothing);
  });
}
