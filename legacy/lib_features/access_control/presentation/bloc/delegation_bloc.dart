import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/models/capability.dart';
import '../../domain/repositories/i_access_control_repository.dart';
import 'delegation_event.dart';
import 'delegation_state.dart';

class DelegationBloc extends Bloc<DelegationEvent, DelegationState> {
  static const int _pageSize = 50;

  final IAccessControlRepository _repository;

  DelegationBloc({required IAccessControlRepository repository})
    : _repository = repository,
      super(const DelegationState()) {
    on<LoadDelegationMembers>(_onLoad);
    on<RefreshDelegationMembers>(_onRefresh);
    on<LoadMoreDelegationMembers>(_onLoadMore);
    on<GrantDelegatedAccess>(_onGrant);
    on<RevokeDelegatedAccess>(_onRevoke);
  }

  Future<void> _onLoad(
    LoadDelegationMembers event,
    Emitter<DelegationState> emit,
  ) async {
    emit(
      DelegationState(
        status: DelegationStatus.loading,
        unitId: event.unitId,
        unitName: event.unitName,
      ),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onRefresh(
    RefreshDelegationMembers event,
    Emitter<DelegationState> emit,
  ) async {
    if (state.unitId.isEmpty || state.status == DelegationStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        status: DelegationStatus.loading,
        clearError: true,
        clearSuccess: true,
      ),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onLoadMore(
    LoadMoreDelegationMembers event,
    Emitter<DelegationState> emit,
  ) async {
    if (!state.hasMore || state.isBusy || state.unitId.isEmpty) return;
    emit(
      state.copyWith(
        status: DelegationStatus.loadingMore,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final page = await _repository.fetchDelegationPage(
        unitId: state.unitId,
        cursor: state.nextCursor,
        limit: _pageSize,
      );
      final byId = {
        for (final member in state.members) member.membershipId: member,
        for (final member in page.members) member.membershipId: member,
      };
      emit(
        state.copyWith(
          status: DelegationStatus.ready,
          members: List.unmodifiable(byId.values),
          delegablePermissions: page.delegablePermissions,
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: DelegationStatus.ready,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onGrant(
    GrantDelegatedAccess event,
    Emitter<DelegationState> emit,
  ) async {
    if (state.unitId.isEmpty || state.isBusy) return;
    emit(
      state.copyWith(
        status: DelegationStatus.submitting,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      await _repository.grantMembership(
        recipientUserId: event.recipientUserId,
        unitId: state.unitId,
        baseRole: BaseRole.delegate.wireValue,
        permissionPreset: event.permissionPreset,
        permissions: event.permissions,
        reason: event.reason,
      );
      await _reloadAfterMutation(emit, AppStrings.accessUpdated);
    } catch (error) {
      emit(
        state.copyWith(
          status: DelegationStatus.ready,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onRevoke(
    RevokeDelegatedAccess event,
    Emitter<DelegationState> emit,
  ) async {
    if (state.unitId.isEmpty || state.isBusy) return;
    emit(
      state.copyWith(
        status: DelegationStatus.submitting,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      await _repository.revokeMembership(
        membershipId: event.membershipId,
        reason: event.reason,
      );
      await _reloadAfterMutation(emit, AppStrings.previousAccessRestored);
    } catch (error) {
      emit(
        state.copyWith(
          status: DelegationStatus.ready,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _loadFirstPage(Emitter<DelegationState> emit) async {
    try {
      final page = await _repository.fetchDelegationPage(
        unitId: state.unitId,
        limit: _pageSize,
      );
      emit(
        state.copyWith(
          status: DelegationStatus.ready,
          members: List.unmodifiable(page.members),
          delegablePermissions: page.delegablePermissions,
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: DelegationStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _reloadAfterMutation(
    Emitter<DelegationState> emit,
    String message,
  ) async {
    final page = await _repository.fetchDelegationPage(
      unitId: state.unitId,
      limit: _pageSize,
    );
    emit(
      state.copyWith(
        status: DelegationStatus.ready,
        members: List.unmodifiable(page.members),
        delegablePermissions: page.delegablePermissions,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        clearError: true,
        successMessage: message,
      ),
    );
  }
}
