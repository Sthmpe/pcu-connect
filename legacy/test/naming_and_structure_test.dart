import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/features/auth/domain/models/user_profile.dart';
import 'package:workflow/features/organization_structure/domain/models/location_model.dart';
import 'package:workflow/features/organization_structure/domain/models/unit_model.dart';
import 'package:workflow/features/organization_structure/presentation/bloc/organization_structure_state.dart';

void main() {
  group('neutral naming model', () {
    test('maps Firebase membership fields without church-specific aliases', () {
      final profile = UserProfile.fromJson(const {
        'id': 'user-1',
        'fullName': 'Ada Operator',
        'phoneE164': '+2348000000000',
        'baseRole': 'unit_manager',
        'organizationId': 'org-1',
        'locationId': 'location-1',
        'unitId': 'unit-1',
        'availabilityStatus': 'inactive',
      });

      expect(profile.role, UserRole.unitManager);
      expect(profile.organizationId, 'org-1');
      expect(profile.locationId, 'location-1');
      expect(profile.unitId, 'unit-1');
      expect(profile.availabilityStatus, 'inactive');
    });
  });

  group('organization structure state', () {
    test('exposes only active locations and units', () {
      const activeLocation = LocationModel(
        id: 'location-1',
        organizationId: 'org-1',
        name: 'Lagos',
        code: 'LOS',
        active: true,
      );
      const archivedLocation = LocationModel(
        id: 'location-2',
        organizationId: 'org-1',
        name: 'Abuja',
        code: 'ABV',
        active: false,
      );
      const activeUnit = UnitModel(
        id: 'unit-1',
        organizationId: 'org-1',
        locationId: 'location-1',
        name: 'Care',
        code: 'CARE',
        active: true,
      );
      const archivedUnit = UnitModel(
        id: 'unit-2',
        organizationId: 'org-1',
        locationId: 'location-1',
        name: 'Archive',
        code: 'OLD',
        active: false,
      );

      const state = OrganizationStructureState(
        status: OrganizationStructureStatus.ready,
        organizationId: 'org-1',
        locations: [activeLocation, archivedLocation],
        units: [activeUnit, archivedUnit],
      );

      expect(state.activeLocations, [activeLocation]);
      expect(state.activeUnits, [activeUnit]);
    });
  });
}
