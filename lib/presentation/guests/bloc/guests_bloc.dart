import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import 'guests_event.dart';
import 'guests_state.dart';

/// The app's guest cache, by month. Screens ask for the months they show
/// ([WatchMonthsEvent]) and keep their own selection, so no screen's month
/// can leak into another's.
class GuestsBloc extends Bloc<GuestsEvent, GuestsState> {
  final IGuestRepository _repo;

  /// One live listener per month (Firestore).
  final Map<String, StreamSubscription<List<GuestEntity>>> _live = {};

  GuestsBloc({required IGuestRepository guestRepository})
      : _repo = guestRepository,
        super(const GuestsState()) {
    on<WatchMonthsEvent>(_onWatch);
    on<RefreshMonthsEvent>(_onRefresh);
    on<ResetGuestsEvent>(_onReset);
    on<GuestsStreamedEvent>(_onStreamed);
    on<GuestsStreamFailedEvent>(_onStreamFailed);
  }

  /// Months with a live listener right now (for tests and diagnostics).
  Set<String> get liveMonths => _live.keys.toSet();

  @override
  Future<void> close() async {
    for (final s in _live.values) {
      await s.cancel();
    }
    _live.clear();
    return super.close();
  }

  Future<void> _onWatch(WatchMonthsEvent event, Emitter<GuestsState> emit) async {
    final todo = <String>[];
    for (final month in event.months.toSet()) {
      final current = state.of(month);
      if (current != null && current.status != MonthStatus.failed) continue;
      if (_live.containsKey(month)) continue;
      final stream = _repo.watchGuests(month: month);
      if (stream != null) {
        emit(state.put(month, MonthGuests(status: MonthStatus.loading, guests: current?.guests ?? const [])));
        _live[month] = stream.listen(
          (guests) => add(GuestsStreamedEvent(month, guests)),
          onError: (Object e) => add(GuestsStreamFailedEvent(month, 'We could not load your guests. Try again.')),
        );
      } else {
        todo.add(month);
      }
    }
    await Future.wait(todo.map((m) => _fetch(m, emit)));
  }

  Future<void> _onRefresh(RefreshMonthsEvent event, Emitter<GuestsState> emit) async {
    final months = (event.months.isEmpty ? state.months.keys : event.months)
        .where((m) => !_live.containsKey(m))
        .toSet();
    await Future.wait(months.map((m) => _fetch(m, emit)));
  }

  /// One month from a source that cannot push updates (the Apps Script API).
  Future<void> _fetch(String month, Emitter<GuestsState> emit) async {
    final previous = state.of(month);
    final cached = previous?.guests.isNotEmpty == true ? null : _repo.getCachedGuests(month: month);
    if (previous != null && previous.hasData) {
      emit(state.put(month, MonthGuests(status: MonthStatus.loaded, guests: previous.guests, refreshing: true)));
    } else if (cached != null && cached.isNotEmpty) {
      emit(state.put(month, MonthGuests(status: MonthStatus.loaded, guests: cached, fromCache: true, refreshing: true)));
    } else {
      emit(state.put(month, const MonthGuests(status: MonthStatus.loading)));
    }

    final result = await _repo.fetchGuests(month: month);
    if (isClosed || state.of(month) == null) return; // reset while waiting
    if (result.isSuccess) {
      emit(state.put(month, MonthGuests(status: MonthStatus.loaded, guests: result.data!)));
      return;
    }
    final now = state.of(month)!;
    emit(state.put(
      month,
      now.guests.isNotEmpty
          ? MonthGuests(status: MonthStatus.loaded, guests: now.guests, fromCache: true)
          : MonthGuests(status: MonthStatus.failed, message: result.failure?.message ?? 'Could not load guests.'),
    ));
  }

  void _onStreamed(GuestsStreamedEvent event, Emitter<GuestsState> emit) {
    if (!_live.containsKey(event.month)) return; // stopped (reset) since
    emit(state.put(event.month, MonthGuests(status: MonthStatus.loaded, guests: event.guests)));
  }

  void _onStreamFailed(GuestsStreamFailedEvent event, Emitter<GuestsState> emit) {
    final sub = _live.remove(event.month);
    if (sub == null) return;
    sub.cancel();
    final now = state.of(event.month);
    emit(state.put(
      event.month,
      now != null && now.guests.isNotEmpty
          ? MonthGuests(status: MonthStatus.loaded, guests: now.guests, fromCache: true)
          // Failed: the next WatchMonthsEvent for this month tries again.
          : MonthGuests(status: MonthStatus.failed, message: event.message),
    ));
  }

  Future<void> _onReset(ResetGuestsEvent event, Emitter<GuestsState> emit) async {
    final subs = _live.values.toList();
    _live.clear();
    for (final s in subs) {
      await s.cancel();
    }
    emit(const GuestsState());
  }
}
