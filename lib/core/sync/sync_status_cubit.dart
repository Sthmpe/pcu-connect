import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'sync_signals.dart';

enum SyncChipState { hidden, offline, syncing, synced }

/// The top bar's sync chip (Firestore mode): "Offline, saves will sync"
/// while offline, "Syncing" while saves or new assignments are on their way,
/// then "All synced" for a moment.
class SyncStatusCubit extends Cubit<SyncChipState> {
  final SyncSignals _signals;
  final Duration grace;
  final Duration syncedFor;
  StreamSubscription<bool>? _online;
  Timer? _graceTimer;
  Timer? _hideTimer;
  bool _isOnline;

  SyncStatusCubit({
    required SyncSignals signals,
    required bool online,
    required Stream<bool> onlineChanges,
    this.grace = const Duration(milliseconds: 400),
    this.syncedFor = const Duration(milliseconds: 2500),
  })  : _signals = signals,
        _isOnline = online,
        super(SyncChipState.hidden) {
    _online = onlineChanges.listen((v) {
      _isOnline = v;
      _update();
    });
    _signals.pendingWrites.addListener(_update);
    _signals.receiving.addListener(_update);
    _update();
  }

  bool get _busy => _signals.pendingWrites.value > 0 || _signals.receiving.value;

  void _update() {
    if (isClosed) return;
    if (!_isOnline) {
      _cancelTimers();
      emit(SyncChipState.offline);
      return;
    }
    if (_busy) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (state == SyncChipState.offline || state == SyncChipState.syncing) {
        emit(SyncChipState.syncing);
      } else {
        // A quick check that settles at once never shows.
        _graceTimer ??= Timer(grace, () {
          _graceTimer = null;
          if (!isClosed && _isOnline && _busy) emit(SyncChipState.syncing);
        });
      }
      return;
    }
    _graceTimer?.cancel();
    _graceTimer = null;
    if (state == SyncChipState.offline || state == SyncChipState.syncing) {
      emit(SyncChipState.synced);
      _hideTimer?.cancel();
      _hideTimer = Timer(syncedFor, () {
        _hideTimer = null;
        if (!isClosed && state == SyncChipState.synced) emit(SyncChipState.hidden);
      });
    }
  }

  void _cancelTimers() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  @override
  Future<void> close() async {
    _cancelTimers();
    _signals.pendingWrites.removeListener(_update);
    _signals.receiving.removeListener(_update);
    await _online?.cancel();
    return super.close();
  }
}
