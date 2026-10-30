import '../../domain/models/location_model.dart';
import '../../domain/models/organization_model.dart';
import '../../domain/models/unit_model.dart';
import '../../domain/repositories/i_organization_structure_repository.dart';
import '../datasources/organization_structure_remote_datasource.dart';

class OrganizationStructureRepositoryImpl
    implements IOrganizationStructureRepository {
  final OrganizationStructureRemoteDatasource _remoteDatasource;

  OrganizationStructureRepositoryImpl({
    OrganizationStructureRemoteDatasource? remoteDatasource,
  }) : _remoteDatasource =
           remoteDatasource ?? OrganizationStructureRemoteDatasource();

  @override
  Future<OrganizationModel?> fetchOrganization(String organizationId) =>
      _remoteDatasource.getOrganization(organizationId);

  @override
  Future<List<LocationModel>> fetchLocations(String organizationId) =>
      _remoteDatasource.getLocations(organizationId);

  @override
  Future<List<UnitModel>> fetchUnits(String organizationId) =>
      _remoteDatasource.getUnits(organizationId);

  @override
  Future<void> saveOrganization({
    required String organizationId,
    required String name,
    required String code,
  }) => _remoteDatasource.saveOrganization(
    organizationId: organizationId,
    name: name,
    code: code,
  );

  @override
  Future<String> createLocation({
    required String organizationId,
    required String name,
    required String code,
  }) => _remoteDatasource.createLocation(
    organizationId: organizationId,
    name: name,
    code: code,
  );

  @override
  Future<void> updateLocation({
    required String locationId,
    required String name,
    required String code,
  }) => _remoteDatasource.updateLocation(
    locationId: locationId,
    name: name,
    code: code,
  );

  @override
  Future<void> archiveLocation(String locationId) =>
      _remoteDatasource.archiveLocation(locationId);

  @override
  Future<String> createUnit({
    required String organizationId,
    required String locationId,
    required String name,
    required String code,
  }) => _remoteDatasource.createUnit(
    organizationId: organizationId,
    locationId: locationId,
    name: name,
    code: code,
  );

  @override
  Future<void> updateUnit({
    required String unitId,
    required String name,
    required String code,
  }) => _remoteDatasource.updateUnit(unitId: unitId, name: name, code: code);

  @override
  Future<void> archiveUnit(String unitId) =>
      _remoteDatasource.archiveUnit(unitId);
}
