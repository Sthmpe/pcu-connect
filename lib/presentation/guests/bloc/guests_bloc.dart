import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/month_utils.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import 'guests_event.dart';
import 'guests_state.dart';

class GuestsBloc extends Bloc<GuestsEvent, GuestsState> {
  final IGuestRepository _guestRepository;

  /// Live subscription when the repository supports it (Firestore).
  StreamSubscription<List<dynamic>>? _live;
  String? _liveMonth;

  GuestsBloc({required IGuestRepository guestRepository})
      : _guestRepository = guestRepository,
        super(GuestsInitialState()) {
    on<LoadGuestsEvent>(_onLoadGuests);
    on<ChangeTileFilterEvent>(_onChangeTileFilter);
    on<ChangeChipFilterEvent>(_onChangeChipFilter);
    on<SelectMonthEvent>(_onSelectMonth);
    on<GuestsStreamedEvent>(_onStreamed);
    on<GuestsStreamFailedEvent>(_onStreamFailed);
  }

  @override
  Future<void> close() async {
    await _live?.cancel();
    return super.close();
  }

  /// Subscribes to the month's live list. Returns false when the repository
  /// has no live source, so the caller falls back to a one-off fetch.
  bool _watch(String month) {
    final stream = _guestRepository.watchGuests(month: month);
    if (stream == null) return false;
    if (_liveMonth == month && _live != null) return true;
    _live?.cancel();
    _liveMonth = month;
    _live = stream.listen(
      (guests) => add(GuestsStreamedEvent(month, guests)),
      onError: (Object e) => add(GuestsStreamFailedEvent(
          month, 'We could not load your guests. Try again.')),
    );
    return true;
  }

  void _onStreamed(GuestsStreamedEvent event, Emitter<GuestsState> emit) {
    if (event.month != _liveMonth) return;
    final previous = state is GuestsLoadedState ? state as GuestsLoadedState : null;
    final same = previous?.selectedMonth == event.month;
    emit(GuestsLoadedState(
      allGuests: event.guests,
      selectedMonth: event.month,
      tileFilter: same ? previous!.tileFilter : 'all',
      chipFilter: same ? previous!.chipFilter : 'all',
    ));
  }

  void _onStreamFailed(GuestsStreamFailedEvent event, Emitter<GuestsState> emit) {
    if (event.month != _liveMonth) return;
    // Let the next load subscribe again.
    _live?.cancel();
    _live = null;
    _liveMonth = null;
    final current = state;
    if (current is GuestsLoadedState) {
      emit(current.copyWith(isFromCache: true, isRefreshing: false));
    } else {
      emit(GuestsFailureState(event.message));
    }
  }

  /// The month currently shown, as an API key ('2026-10').
  String get _currentMonth {
    final s = state;
    return s is GuestsLoadedState ? s.selectedMonth : MonthUtils.current();
  }

  Future<void> _onLoadGuests(
    LoadGuestsEvent event,
    Emitter<GuestsState> emit,
  ) async {
    final month = event.month ?? _currentMonth;
    final previous = state is GuestsLoadedState ? state as GuestsLoadedState : null;
    final sameMonth = previous?.selectedMonth == month;

    // Live source: the stream delivers the list and every later change.
    if (_guestRepository.watchGuests(month: month) != null) {
      if (!sameMonth) emit(GuestsLoadingState());
      if (_liveMonth != month || _live == null) _watch(month);
      return;
    }

    final cached = _guestRepository.getCachedGuests(month: month);
    if (sameMonth) {
      emit(previous!.copyWith(isRefreshing: true));
    } else if (cached != null && cached.isNotEmpty) {
      emit(GuestsLoadedState(
        allGuests: cached,
        selectedMonth: month,
        isFromCache: true,
        isRefreshing: true,
      ));
    } else {
      emit(GuestsLoadingState());
    }

    final result = await _guestRepository.fetchGuests(month: month);
    if (result.isSuccess) {
      emit(GuestsLoadedState(
        allGuests: result.data!,
        selectedMonth: month,
        tileFilter: sameMonth ? previous!.tileFilter : 'all',
        chipFilter: sameMonth ? previous!.chipFilter : 'all',
      ));
      return;
    }

    final current = state;
    if (current is GuestsLoadedState) {
      emit(current.copyWith(isFromCache: true, isRefreshing: false));
    } else {
      emit(GuestsFailureState(result.failure?.message ?? 'Could not load guests.'));
    }
  }

  void _onChangeTileFilter(
    ChangeTileFilterEvent event,
    Emitter<GuestsState> emit,
  ) {
    if (state is GuestsLoadedState) {
      final current = state as GuestsLoadedState;
      final newTile = current.tileFilter == event.tile ? 'all' : event.tile;
      emit(current.copyWith(tileFilter: newTile));
    }
  }

  void _onChangeChipFilter(
    ChangeChipFilterEvent event,
    Emitter<GuestsState> emit,
  ) {
    if (state is GuestsLoadedState) {
      final current = state as GuestsLoadedState;
      emit(current.copyWith(chipFilter: event.chip));
    }
  }

  /// Guests are fetched per month, so a new month means a new request.
  Future<void> _onSelectMonth(
    SelectMonthEvent event,
    Emitter<GuestsState> emit,
  ) =>
      _onLoadGuests(LoadGuestsEvent(month: event.month), emit);
}
