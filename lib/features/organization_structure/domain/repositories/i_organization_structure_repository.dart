import '../models/location_model.dart';
import '../models/organization_model.dart';
import '../models/unit_model.dart';

abstract class IOrganizationStructureRepository {
  Future<OrganizationModel?> fetchOrganization(String organizationId);

  Future<List<LocationModel>> fetchLocations(String organizationId);

  Future<List<UnitModel>> fetchUnits(String organizationId);

  Future<void> saveOrganization({
    required String organizationId,
    required String name,
    required String code,
  });

  Future<String> createLocation({
    required String organizationId,
    required String name,
    required String code,
  });

  Future<void> updateLocation({
    required String locationId,
    required String name,
    required String code,
  });

  Future<void> archiveLocation(String locationId);

  Future<String> createUnit({
    required String organizationId,
    required String locationId,
    required String name,
    required String code,
  });

  Future<void> updateUnit({
    required String unitId,
    required String name,
    required String code,
  });

  Future<void> archiveUnit(String unitId);
}
