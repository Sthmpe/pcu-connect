import 'package:equatable/equatable.dart';

enum UserRole { organizationOwner, unitManager, delegate, operator, viewer }

class UserProfile extends Equatable {
  final String id;
  final String fullName;
  final String? phoneE164;
  final UserRole role;
  final String organizationId;
  final String locationId;
  final String unitId;
  final String availabilityStatus;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.phoneE164,
    required this.role,
    required this.organizationId,
    required this.locationId,
    required this.unitId,
    required this.availabilityStatus,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? 'User',
      phoneE164: json['phoneE164'] as String?,
      role: _parseRole(json['baseRole'] as String?),
      organizationId: json['organizationId'] as String? ?? '',
      locationId: json['locationId'] as String? ?? '',
      unitId: json['unitId'] as String? ?? '',
      availabilityStatus: json['availabilityStatus'] as String? ?? 'active',
    );
  }

  static UserRole _parseRole(String? roleStr) {
    switch (roleStr) {
      case 'organization_owner':
        return UserRole.organizationOwner;
      case 'unit_manager':
        return UserRole.unitManager;
      case 'delegate':
        return UserRole.delegate;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.operator;
    }
  }

  @override
  List<Object?> get props => [
    id,
    fullName,
    phoneE164,
    role,
    organizationId,
    locationId,
    unitId,
    availabilityStatus,
  ];
}
