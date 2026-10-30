import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/i_guest_repository.dart';
import 'guest_event.dart';
import 'guest_state.dart';

class GuestBloc extends Bloc<GuestEvent, GuestState> {
  final IGuestRepository _guestRepository;

  GuestBloc({required IGuestRepository guestRepository})
    : _guestRepository = guestRepository,
      super(const GuestInitial()) {
    on<LoadAssignedGuests>(_onLoadAssignedGuests);
    on<LoadUnitContacts>(_onLoadUnitContacts);
    on<LoadContactDetail>(_onLoadContactDetail);
  }

  Future<void> _onLoadAssignedGuests(
    LoadAssignedGuests event,
    Emitter<GuestState> emit,
  ) async {
    emit(const GuestLoading());
    try {
      final guests = await _guestRepository.fetchAssignedGuests(
        operatorId: event.operatorId,
        stageFilter: event.stageFilter,
      );
      emit(GuestLoaded(guests));
    } catch (e) {
      emit(GuestFailure(e.toString()));
    }
  }

  Future<void> _onLoadUnitContacts(
    LoadUnitContacts event,
    Emitter<GuestState> emit,
  ) async {
    emit(const GuestLoading());
    try {
      final guests = await _guestRepository.fetchAllUnitContacts(
        unitId: event.unitId,
        stageFilter: event.stageFilter,
      );
      emit(GuestLoaded(guests));
    } catch (e) {
      emit(GuestFailure(e.toString()));
    }
  }

  Future<void> _onLoadContactDetail(
    LoadContactDetail event,
    Emitter<GuestState> emit,
  ) async {
    emit(const GuestDetailLoading());
    try {
      final guest = await _guestRepository.fetchContactDetail(event.contactId);
      if (guest != null) {
        emit(GuestDetailLoaded(guest));
      } else {
        emit(const GuestDetailFailure('Guest not found'));
      }
    } catch (e) {
      emit(GuestDetailFailure(e.toString()));
    }
  }
}
