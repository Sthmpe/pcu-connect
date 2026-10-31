import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/month_utils.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import 'guests_event.dart';
import 'guests_state.dart';

class GuestsBloc extends Bloc<GuestsEvent, GuestsState> {
  final IGuestRepository _guestRepository;

  GuestsBloc({required IGuestRepository guestRepository})
      : _guestRepository = guestRepository,
        super(GuestsInitialState()) {
    on<LoadGuestsEvent>(_onLoadGuests);
    on<ChangeTileFilterEvent>(_onChangeTileFilter);
    on<ChangeChipFilterEvent>(_onChangeChipFilter);
    on<SelectMonthEvent>(_onSelectMonth);
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
