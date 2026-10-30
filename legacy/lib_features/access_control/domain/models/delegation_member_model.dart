import 'package:equatable/equatable.dart';

import 'capability.dart';

class DelegationMemberModel extends Equatable {
  final String membershipId;
  final String userId;
  final String displayName;
  final BaseRole baseRole;
  final String permissionPreset;
  final List<String> permissions;
  final String availabilityStatus;
  final bool isDelegated;
  final bool canManage;

  const DelegationMemberModel({
    required this.membershipId,
    required this.userId,
    required this.displayName,
    required this.baseRole,
    required this.permissionPreset,
    required this.permissions,
    required this.availabilityStatus,
    required this.isDelegated,
    required this.canManage,
  });

  factory DelegationMemberModel.fromJson(Map<String, dynamic> json) {
    final permissions = List<String>.from(
      json['permissions'] as List? ?? const [],
    )..sort();

    return DelegationMemberModel(
      membershipId: json['membershipId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      baseRole: BaseRole.fromString(json['baseRole'] as String? ?? 'operator'),
      permissionPreset: json['permissionPreset'] as String? ?? 'custom',
      permissions: List.unmodifiable(permissions),
      availabilityStatus: json['availabilityStatus'] as String? ?? 'inactive',
      isDelegated: json['isDelegated'] as bool? ?? false,
      canManage: json['canManage'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    membershipId,
    userId,
    displayName,
    baseRole,
    permissionPreset,
    permissions,
    availabilityStatus,
    isDelegated,
    canManage,
  ];
}

class DelegationPageResult extends Equatable {
  final List<DelegationMemberModel> members;
  final Set<String> delegablePermissions;
  final String? nextCursor;

  const DelegationPageResult({
    required this.members,
    required this.delegablePermissions,
    this.nextCursor,
  });

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  @override
  List<Object?> get props => [members, delegablePermissions, nextCursor];
}
