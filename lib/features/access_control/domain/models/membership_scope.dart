import 'package:equatable/equatable.dart';

/// What part of the org tree this membership applies to. An empty
/// [locationIds]/[unitIds] list means "organization-wide" for that level -
/// e.g. an org-wide HOD has locationIds: [] but a campus-bound HOD lists
/// specific location ids.
class MembershipScope extends Equatable {
  final String organizationId;
  final List<String> locationIds;
  final List<String> unitIds;

  const MembershipScope({
    required this.organizationId,
    this.locationIds = const [],
    this.unitIds = const [],
  });

  bool get isOrganizationWide => locationIds.isEmpty;

  bool covers({
    required String organizationId,
    String? locationId,
    String? unitId,
  }) {
    if (this.organizationId != organizationId) return false;
    if (locationIds.isNotEmpty &&
        locationId != null &&
        !locationIds.contains(locationId)) {
      return false;
    }
    if (unitIds.isNotEmpty && unitId != null && !unitIds.contains(unitId)) {
      return false;
    }
    return true;
  }

  factory MembershipScope.fromJson(Map<String, dynamic> json) {
    return MembershipScope(
      organizationId: json['organizationId'] as String? ?? '',
      locationIds: List<String>.from(json['locationIds'] as List? ?? const []),
      unitIds: List<String>.from(json['unitIds'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toJson() => {
    'organizationId': organizationId,
    'locationIds': locationIds,
    'unitIds': unitIds,
  };

  @override
  List<Object?> get props => [organizationId, locationIds, unitIds];
}
