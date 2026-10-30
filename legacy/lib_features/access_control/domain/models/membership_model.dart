import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'capability.dart';
import 'membership_scope.dart';

/// `team_memberships/{unitId_userId}`. This is the single document the
/// app reads to decide what a signed-in user can do - everything else is
/// derived from it (AccessCubit, Firestore rules, edge function checks).
class MembershipModel extends Equatable {
  final String id;
  final String userId;
  final MembershipScope scope;
  final BaseRole baseRole;
  final String permissionPreset;
  final Map<String, bool> permissions;
  final bool active;
  final String? grantedBy;
  final DateTime? grantedAt;
  final int permissionVersion;

  const MembershipModel({
    required this.id,
    required this.userId,
    required this.scope,
    required this.baseRole,
    required this.permissionPreset,
    required this.permissions,
    required this.active,
    this.grantedBy,
    this.grantedAt,
    this.permissionVersion = 1,
  });

  bool can(String capability) => active && (permissions[capability] ?? false);

  factory MembershipModel.fromJson(String id, Map<String, dynamic> json) {
    return MembershipModel(
      id: id,
      userId: json['userId'] as String? ?? '',
      scope: MembershipScope.fromJson(
        Map<String, dynamic>.from(json['scope'] as Map? ?? const {}),
      ),
      baseRole: BaseRole.fromString(json['baseRole'] as String? ?? 'operator'),
      permissionPreset: json['permissionPreset'] as String? ?? 'custom',
      permissions: Map<String, bool>.from(
        json['permissions'] as Map? ?? const {},
      ),
      active: json['active'] as bool? ?? false,
      grantedBy: json['grantedBy'] as String?,
      grantedAt: json['grantedAt'] is Timestamp
          ? (json['grantedAt'] as Timestamp).toDate()
          : null,
      permissionVersion: json['permissionVersion'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    scope,
    baseRole,
    permissionPreset,
    permissions,
    active,
    grantedBy,
    grantedAt,
    permissionVersion,
  ];
}
