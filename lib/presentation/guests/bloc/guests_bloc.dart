import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import 'guests_event.dart';
import 'guests_state.dart';

class GuestsBloc extends Bloc<GuestsEvent, GuestsState> {
  final IGuestRepository _guestRepository;

  // Fallback initial dataset matching PCU_Worker_App.html prototype for instant dev/offline feedback
  static const List<GuestEntity> seedGuests = [
    GuestEntity(
      id: 'G1',
      name: 'Chiamaka Obi',
      phone: '0803 555 0101',
      status: 'New guest',
      daysSinceVisit: 4,
      callCount: 0,
      sundayAttendance: 1,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: 0,
      month: 'Oct 2026',
    ),
    GuestEntity(
      id: 'G2',
      name: 'Tunde Bakare',
      phone: '0803 555 0102',
      status: 'Contacted',
      daysSinceVisit: 2,
      callCount: 1,
      sundayAttendance: 2,
      wednesdayAttendance: 1,
      teamJoined: '',
      lastFeedback: 'Enjoyed the service, will be back Sunday.',
      lastFeedbackDate: '26 Oct',
      followUpCount: 1,
      month: 'Oct 2026',
    ),
    GuestEntity(
      id: 'G3',
      name: 'Esther Adeyemi',
      phone: '0803 555 0103',
      status: 'Returning',
      daysSinceVisit: 12,
      callCount: 3,
      sundayAttendance: 3,
      wednesdayAttendance: 2,
      teamJoined: 'Workforce',
      lastFeedback: 'Asked about joining Workforce.',
      lastFeedbackDate: '27 Oct',
      followUpCount: 3,
      month: 'Oct 2026',
    ),
    GuestEntity(
      id: 'G4',
      name: 'Samuel Eze',
      phone: '0803 555 0104',
      status: 'Member',
      daysSinceVisit: 20,
      callCount: 5,
      sundayAttendance: 4,
      wednesdayAttendance: 2,
      teamJoined: 'Evangelism',
      lastFeedback: 'Now a member. Joined Evangelism.',
      lastFeedbackDate: '25 Oct',
      followUpCount: 5,
      month: 'Oct 2026',
    ),
    GuestEntity(
      id: 'G5',
      name: 'Ngozi Umeh',
      phone: '0803 555 0105',
      status: 'New guest',
      daysSinceVisit: 1,
      callCount: 0,
      sundayAttendance: 1,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: 0,
      month: 'Oct 2026',
    ),
    GuestEntity(
      id: 'G6',
      name: 'Femi Ajayi',
      phone: '0803 555 0106',
      status: 'Unreachable',
      daysSinceVisit: 15,
      callCount: 3,
      sundayAttendance: 1,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: 'Phone off on 3 tries.',
      lastFeedbackDate: '20 Oct',
      followUpCount: 3,
      month: 'Oct 2026',
    ),
    GuestEntity(
      id: 'G7',
      name: 'Bola Ogun',
      phone: '0803 555 0107',
      status: 'Returning',
      daysSinceVisit: 40,
      callCount: 4,
      sundayAttendance: 2,
      wednesdayAttendance: 1,
      teamJoined: '',
      lastFeedback: 'Travelling, back next month.',
      lastFeedbackDate: '12 Sep',
      followUpCount: 4,
      month: 'Sep 2026',
    ),
    GuestEntity(
      id: 'G8',
      name: 'Dayo Balogun',
      phone: '0803 555 0108',
      status: 'Member',
      daysSinceVisit: 55,
      callCount: 6,
      sundayAttendance: 4,
      wednesdayAttendance: 3,
      teamJoined: 'Workforce',
      lastFeedback: 'Became a member.',
      lastFeedbackDate: '30 Sep',
      followUpCount: 6,
      month: 'Sep 2026',
    ),
    GuestEntity(
      id: 'G9',
      name: 'Kemi Lawal',
      phone: '0803 555 0109',
      status: 'Not interested',
      daysSinceVisit: 70,
      callCount: 2,
      sundayAttendance: 1,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: 'Prefers another church.',
      lastFeedbackDate: '8 Aug',
      followUpCount: 2,
      month: 'Aug 2026',
    ),
  ];

  GuestsBloc({required IGuestRepository guestRepository})
      : _guestRepository = guestRepository,
        super(GuestsInitialState()) {
    on<LoadGuestsEvent>(_onLoadGuests);
    on<ChangeTileFilterEvent>(_onChangeTileFilter);
    on<ChangeChipFilterEvent>(_onChangeChipFilter);
    on<SelectMonthEvent>(_onSelectMonth);
  }

  Future<void> _onLoadGuests(
    LoadGuestsEvent event,
    Emitter<GuestsState> emit,
  ) async {
    final currentMonth = event.month ?? 'Oct 2026';

    final cached = _guestRepository.getCachedGuests(month: currentMonth);
    if (cached != null && cached.isNotEmpty) {
      emit(GuestsLoadedState(
        allGuests: cached,
        selectedMonth: currentMonth,
        isFromCache: true,
        isRefreshing: true,
      ));
    } else {
      emit(GuestsLoadingState());
    }

    final result = await _guestRepository.fetchGuests(month: currentMonth);
    if (result.isSuccess && result.data!.isNotEmpty) {
      emit(GuestsLoadedState(
        allGuests: result.data!,
        selectedMonth: currentMonth,
        isFromCache: false,
        isRefreshing: false,
      ));
    } else {
      if (state is GuestsLoadedState) {
        final current = state as GuestsLoadedState;
        emit(current.copyWith(isFromCache: true, isRefreshing: false));
      } else {
        emit(GuestsLoadedState(
          allGuests: seedGuests,
          selectedMonth: currentMonth,
          isFromCache: true,
          isRefreshing: false,
        ));
      }
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

  void _onSelectMonth(
    SelectMonthEvent event,
    Emitter<GuestsState> emit,
  ) {
    if (state is GuestsLoadedState) {
      final current = state as GuestsLoadedState;
      emit(current.copyWith(selectedMonth: event.month));
    }
  }
}
