import 'package:equatable/equatable.dart';

import '../../domain/models/location_model.dart';
import '../../domain/models/organization_model.dart';
import '../../domain/models/unit_model.dart';

enum OrganizationStructureStatus { initial, loading, ready, saving, failure }

class OrganizationStructureState extends Equatable {
  final OrganizationStructureStatus status;
  final String organizationId;
  final OrganizationModel? organization;
  final List<LocationModel> locations;
  final List<UnitModel> units;
  final String? errorMessage;

  const OrganizationStructureState({
    this.status = OrganizationStructureStatus.initial,
    this.organizationId = '',
    this.organization,
    this.locations = const [],
    this.units = const [],
    this.errorMessage,
  });

  OrganizationStructureState copyWith({
    OrganizationStructureStatus? status,
    String? organizationId,
    OrganizationModel? organization,
    bool clearOrganization = false,
    List<LocationModel>? locations,
    List<UnitModel>? units,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OrganizationStructureState(
      status: status ?? this.status,
      organizationId: organizationId ?? this.organizationId,
      organization: clearOrganization
          ? null
          : organization ?? this.organization,
      locations: locations ?? this.locations,
      units: units ?? this.units,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  List<LocationModel> get activeLocations =>
      locations.where((location) => location.active).toList(growable: false);

  List<UnitModel> get activeUnits =>
      units.where((unit) => unit.active).toList(growable: false);

  @override
  List<Object?> get props => [
    status,
    organizationId,
    organization,
    locations,
    units,
    errorMessage,
  ];
}
