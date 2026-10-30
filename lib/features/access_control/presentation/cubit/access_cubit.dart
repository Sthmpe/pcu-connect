import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/i_access_control_repository.dart';
import 'access_state.dart';

/// Single source of truth for "what can the current user do in this unit".
/// Loaded once per unit context and read everywhere via `context.select`
/// or `BlocSelector<AccessCubit, AccessState, bool>` scoped to one
/// capability - so a button tied to `workers.add` doesn't rebuild when an
/// unrelated capability like `reports.view_unit` is what actually changed.
///
/// This is a read model only. It never grants access itself - it mirrors
/// the membership doc that Firestore rules and the manage-access Edge
/// Function are the real authority on.
class AccessCubit extends Cubit<AccessState> {
  final IAccessControlRepository _repository;

  AccessCubit({required IAccessControlRepository repository})
    : _repository = repository,
      super(const AccessLoading());

  Future<void> loadForUnit(String unitId) async {
    emit(const AccessLoading());
    try {
      final membership = await _repository.fetchOwnMembership(unitId: unitId);
      if (membership == null || !membership.active) {
        emit(const AccessDenied());
      } else {
        emit(AccessReady(membership));
      }
    } catch (e) {
      emit(AccessFailure(e.toString()));
    }
  }

  bool can(String capability) {
    final current = state;
    return current is AccessReady && current.can(capability);
  }

  void reset() => emit(const AccessDenied());
}
