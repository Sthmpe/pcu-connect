import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/firestore/sheet_sync_repository.dart';
import '../../../domain/entities/sheet_sync.dart';

class SheetSyncState extends Equatable {
  final SheetSyncStatus status;

  /// True while this device waits for "Sync to sheet" to finish.
  final bool syncing;

  /// The outcome of the last tap, for a short note under the button.
  final String? message;
  final bool messageIsError;

  const SheetSyncState({
    this.status = const SheetSyncStatus(),
    this.syncing = false,
    this.message,
    this.messageIsError = false,
  });

  /// Busy here, or a nightly run in progress on the server.
  bool get busy => syncing || status.running;

  SheetSyncState copyWith({
    SheetSyncStatus? status,
    bool? syncing,
    String? message,
    bool? messageIsError,
  }) =>
      SheetSyncState(
        status: status ?? this.status,
        syncing: syncing ?? this.syncing,
        message: message,
        messageIsError: messageIsError ?? false,
      );

  @override
  List<Object?> get props => [status, syncing, message, messageIsError];
}

/// HOD only: the "Last synced" line (live from meta/sync) and "Sync to sheet".
class SheetSyncCubit extends Cubit<SheetSyncState> {
  final ISheetSyncRepository _repo;
  StreamSubscription<SheetSyncStatus>? _sub;

  /// Called after a sync that changed something, to refresh the dashboard.
  final void Function()? onSynced;

  SheetSyncCubit(this._repo, {this.onSynced}) : super(const SheetSyncState()) {
    _sub = _repo.watch().listen(
      (s) => emit(state.copyWith(status: s, message: state.message, messageIsError: state.messageIsError)),
      // The status line just stays as it was; the button still works.
      onError: (_) {},
    );
  }

  Future<void> syncNow() async {
    if (state.busy) return;
    emit(state.copyWith(syncing: true));
    final result = await _repo.syncNow();
    if (isClosed) return;
    if (result.isSuccess) {
      final done = result.data!;
      emit(state.copyWith(syncing: false, message: done.message));
      if (done.followUps > 0 || done.guests > 0) onSynced?.call();
    } else {
      emit(state.copyWith(
        syncing: false,
        message: result.failure?.message ?? 'We could not sync to the sheet. Try again.',
        messageIsError: true,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
