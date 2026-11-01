import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../data/firestore/worker_calls_repository.dart';
import '../../../domain/today_rules.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';

class TodayState extends Equatable {
  final bool loading;
  final String? failure;
  final TodayView view;
  final bool fromCache;
  final bool refreshing;
  final List<String> months;

  const TodayState({
    this.loading = true,
    this.failure,
    this.view = const TodayView(),
    this.fromCache = false,
    this.refreshing = false,
    this.months = const [],
  });

  @override
  List<Object?> get props => [loading, failure, view.all.map((i) => '${i.guest.id}:${i.section}:${i.days}').join(','), view.doneToday, fromCache, refreshing, months];
}

/// The worker's to-do list, live: guests from the shared cache (the months
/// since go-live, never a screen's month filter) plus the worker's own calls.
/// Recomputed when either changes and at Lagos midnight. Feeds the Today tab,
/// its bottom navigation badge and the daily goal ring.
class TodayCubit extends Cubit<TodayState> {
  final GuestsBloc _guests;
  final IWorkerCallsRepository? _calls;
  final String Function() _worker;
  final DateTime Function() _clock;
  final String since;

  StreamSubscription<GuestsState>? _guestsSub;
  StreamSubscription<List<CallRecord>>? _callsSub;
  Timer? _midnight;
  List<CallRecord>? _callRecords;

  TodayCubit({
    required GuestsBloc guests,
    required String Function() worker,
    required this.since,
    IWorkerCallsRepository? calls,
    DateTime Function()? clock,
  })  : _guests = guests,
        _calls = calls,
        _worker = worker,
        _clock = clock ?? DateTime.now,
        super(const TodayState());

  String get _today => LagosTime.today(_clock());

  void start() {
    _watchMonths();
    _guestsSub ??= _guests.stream.listen((_) => _recompute());
    final stream = _calls?.watch();
    if (stream != null && _callsSub == null) {
      _callsSub = stream.listen((calls) {
        _callRecords = calls;
        _recompute();
      }, onError: (_) {});
    }
    _scheduleMidnight();
    _recompute();
  }

  void _watchMonths() {
    final months = TodayRules.months(since: since, today: _today);
    _guests.add(WatchMonthsEvent(months));
    if (!isClosed) emit(_with(months: months));
  }

  /// The next Lagos midnight: the date changes, so sections and the ring do too.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = _clock().toUtc();
    final lagos = now.add(LagosTime.offset);
    final next = DateTime.utc(lagos.year, lagos.month, lagos.day + 1).subtract(LagosTime.offset);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      _watchMonths();
      _recompute();
      _scheduleMidnight();
    });
  }

  /// For tests: recompute as if the clock moved on.
  void refreshNow() {
    _watchMonths();
    _recompute();
  }

  TodayState _with({List<String>? months}) => TodayState(
        loading: state.loading,
        failure: state.failure,
        view: state.view,
        fromCache: state.fromCache,
        refreshing: state.refreshing,
        months: months ?? state.months,
      );

  void _recompute() {
    if (isClosed) return;
    final months = state.months.isEmpty ? TodayRules.months(since: since, today: _today) : state.months;
    final g = _guests.state;
    final failure = g.failureFor(months);
    if (failure != null) {
      emit(TodayState(loading: false, failure: failure, months: months));
      return;
    }
    if (g.waitingFor(months)) {
      emit(TodayState(loading: true, months: months));
      return;
    }
    final today = _today;
    final calls = _callRecords;
    final view = TodayRules.build(
      guests: g.guestsIn(months),
      since: since,
      today: today,
      calls: calls == null ? const {} : TodayRules.summarise(calls),
      doneToday: calls == null
          // Apps Script source: the guests' own last call day (may include saves an admin made).
          ? g.guestsIn(months).where((x) => x.lastCallDate == today).length
          : TodayRules.doneToday(calls, worker: _worker(), today: today),
    );
    emit(TodayState(
      loading: false,
      view: view,
      fromCache: g.fromCacheIn(months),
      refreshing: g.refreshingIn(months),
      months: months,
    ));
  }

  @override
  Future<void> close() async {
    _midnight?.cancel();
    await _guestsSub?.cancel();
    await _callsSub?.cancel();
    return super.close();
  }
}
