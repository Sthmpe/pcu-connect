import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/features/access_control/domain/models/capability.dart';
import 'package:workflow/features/access_control/domain/models/delegation_member_model.dart';
import 'package:workflow/features/access_control/domain/models/permission_preset.dart';

void main() {
  group('permission presets', () {
    test('round-trip all wire values', () {
      for (final preset in PermissionPreset.values) {
        expect(PermissionPreset.fromWireValue(preset.wireValue), preset);
      }
    });

    test('deputy receives operational permissions but cannot redelegate', () {
      const available = {
        Capability.contactsViewAll,
        Capability.assignmentsManage,
        Capability.permissionsDelegate,
      };

      final resolved = PermissionPreset.deputyManager.resolvePermissions(
        available,
      );

      expect(resolved, contains(Capability.contactsViewAll));
      expect(resolved, contains(Capability.assignmentsManage));
      expect(resolved, isNot(contains(Capability.permissionsDelegate)));
    });

    test('preset is unavailable when caller lacks one of its permissions', () {
      expect(
        PermissionPreset.assignmentOfficer.isAvailableWithin(const {
          Capability.contactsViewAll,
          Capability.assignmentsView,
          Capability.assignmentsManage,
        }),
        isFalse,
      );
    });
  });

  group('delegation member model', () {
    test('maps the sanitized Edge Function projection', () {
      final member = DelegationMemberModel.fromJson(const {
        'membershipId': 'unit-1_user-1',
        'userId': 'user-1',
        'displayName': 'Ada Worker',
        'baseRole': 'delegate',
        'permissionPreset': 'assignment_officer',
        'permissions': [Capability.workersView, Capability.assignmentsManage],
        'availabilityStatus': 'inactive',
        'isDelegated': true,
        'canManage': true,
      });

      expect(member.membershipId, 'unit-1_user-1');
      expect(member.baseRole, BaseRole.delegate);
      expect(member.isDelegated, isTrue);
      expect(member.canManage, isTrue);
      expect(member.permissions, [
        Capability.assignmentsManage,
        Capability.workersView,
      ]);
    });

    test('uses safe defaults for optional projection fields', () {
      final member = DelegationMemberModel.fromJson(const {});

      expect(member.baseRole, BaseRole.operator);
      expect(member.permissionPreset, PermissionPreset.custom.wireValue);
      expect(member.permissions, isEmpty);
      expect(member.isDelegated, isFalse);
      expect(member.canManage, isFalse);
    });
  });
}
