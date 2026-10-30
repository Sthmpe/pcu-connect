import 'package:equatable/equatable.dart';

import '../../domain/models/delegation_member_model.dart';

enum DelegationStatus {
  initial,
  loading,
  ready,
  loadingMore,
  submitting,
  failure,
}

class DelegationState extends Equatable {
  final DelegationStatus status;
  final String unitId;
  final String unitName;
  final List<DelegationMemberModel> members;
  final Set<String> delegablePermissions;
  final String? nextCursor;
  final String? errorMessage;
  final String? successMessage;

  const DelegationState({
    this.status = DelegationStatus.initial,
    this.unitId = '',
    this.unitName = '',
    this.members = const [],
    this.delegablePermissions = const {},
    this.nextCursor,
    this.errorMessage,
    this.successMessage,
  });

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
  bool get isBusy =>
      status == DelegationStatus.loading ||
      status == DelegationStatus.loadingMore ||
      status == DelegationStatus.submitting;

  DelegationState copyWith({
    DelegationStatus? status,
    String? unitId,
    String? unitName,
    List<DelegationMemberModel>? members,
    Set<String>? delegablePermissions,
    String? nextCursor,
    bool clearCursor = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return DelegationState(
      status: status ?? this.status,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      members: members ?? this.members,
      delegablePermissions: delegablePermissions ?? this.delegablePermissions,
      nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    unitId,
    unitName,
    members,
    delegablePermissions,
    nextCursor,
    errorMessage,
    successMessage,
  ];
}
