import 'package:equatable/equatable.dart';

sealed class OrganizationStructureEvent extends Equatable {
  const OrganizationStructureEvent();

  @override
  List<Object?> get props => [];
}

final class LoadOrganizationStructure extends OrganizationStructureEvent {
  final String organizationId;

  const LoadOrganizationStructure(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

final class SaveOrganization extends OrganizationStructureEvent {
  final String name;
  final String code;

  const SaveOrganization({required this.name, required this.code});

  @override
  List<Object?> get props => [name, code];
}

final class CreateLocation extends OrganizationStructureEvent {
  final String name;
  final String code;

  const CreateLocation({required this.name, required this.code});

  @override
  List<Object?> get props => [name, code];
}

final class UpdateLocation extends OrganizationStructureEvent {
  final String locationId;
  final String name;
  final String code;

  const UpdateLocation({
    required this.locationId,
    required this.name,
    required this.code,
  });

  @override
  List<Object?> get props => [locationId, name, code];
}

final class ArchiveLocation extends OrganizationStructureEvent {
  final String locationId;

  const ArchiveLocation(this.locationId);

  @override
  List<Object?> get props => [locationId];
}

final class CreateUnit extends OrganizationStructureEvent {
  final String locationId;
  final String name;
  final String code;

  const CreateUnit({
    required this.locationId,
    required this.name,
    required this.code,
  });

  @override
  List<Object?> get props => [locationId, name, code];
}

final class UpdateUnit extends OrganizationStructureEvent {
  final String unitId;
  final String name;
  final String code;

  const UpdateUnit({
    required this.unitId,
    required this.name,
    required this.code,
  });

  @override
  List<Object?> get props => [unitId, name, code];
}

final class ArchiveUnit extends OrganizationStructureEvent {
  final String unitId;

  const ArchiveUnit(this.unitId);

  @override
  List<Object?> get props => [unitId];
}
