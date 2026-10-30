import 'package:equatable/equatable.dart';

sealed class DelegationEvent extends Equatable {
  const DelegationEvent();

  @override
  List<Object?> get props => [];
}

final class LoadDelegationMembers extends DelegationEvent {
  final String unitId;
  final String unitName;

  const LoadDelegationMembers({required this.unitId, required this.unitName});

  @override
  List<Object?> get props => [unitId, unitName];
}

final class RefreshDelegationMembers extends DelegationEvent {
  const RefreshDelegationMembers();
}

final class LoadMoreDelegationMembers extends DelegationEvent {
  const LoadMoreDelegationMembers();
}

final class GrantDelegatedAccess extends DelegationEvent {
  final String recipientUserId;
  final String permissionPreset;
  final Set<String> permissions;
  final String? reason;

  const GrantDelegatedAccess({
    required this.recipientUserId,
    required this.permissionPreset,
    required this.permissions,
    this.reason,
  });

  @override
  List<Object?> get props => [
    recipientUserId,
    permissionPreset,
    permissions,
    reason,
  ];
}

final class RevokeDelegatedAccess extends DelegationEvent {
  final String membershipId;
  final String? reason;

  const RevokeDelegatedAccess({required this.membershipId, this.reason});

  @override
  List<Object?> get props => [membershipId, reason];
}
