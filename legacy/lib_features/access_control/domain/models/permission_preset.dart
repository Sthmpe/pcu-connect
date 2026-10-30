import 'capability.dart';

/// Presets are UI conveniences. The server validates the expanded permission
/// set and never trusts the preset name as authority.
enum PermissionPreset {
  assignmentOfficer,
  followUpSupervisor,
  recordsOfficer,
  reportingOfficer,
  teamOfficer,
  deputyManager,
  custom;

  static PermissionPreset fromWireValue(String value) {
    switch (value) {
      case 'assignment_officer':
        return PermissionPreset.assignmentOfficer;
      case 'follow_up_supervisor':
        return PermissionPreset.followUpSupervisor;
      case 'records_officer':
        return PermissionPreset.recordsOfficer;
      case 'reporting_officer':
        return PermissionPreset.reportingOfficer;
      case 'team_officer':
        return PermissionPreset.teamOfficer;
      case 'deputy_manager':
        return PermissionPreset.deputyManager;
      default:
        return PermissionPreset.custom;
    }
  }

  String get wireValue {
    switch (this) {
      case PermissionPreset.assignmentOfficer:
        return 'assignment_officer';
      case PermissionPreset.followUpSupervisor:
        return 'follow_up_supervisor';
      case PermissionPreset.recordsOfficer:
        return 'records_officer';
      case PermissionPreset.reportingOfficer:
        return 'reporting_officer';
      case PermissionPreset.teamOfficer:
        return 'team_officer';
      case PermissionPreset.deputyManager:
        return 'deputy_manager';
      case PermissionPreset.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case PermissionPreset.assignmentOfficer:
        return 'Assignment Officer';
      case PermissionPreset.followUpSupervisor:
        return 'Follow-up Supervisor';
      case PermissionPreset.recordsOfficer:
        return 'Records Officer';
      case PermissionPreset.reportingOfficer:
        return 'Reporting Officer';
      case PermissionPreset.teamOfficer:
        return 'Team Officer';
      case PermissionPreset.deputyManager:
        return 'Deputy Manager';
      case PermissionPreset.custom:
        return 'Custom';
    }
  }

  Set<String> get capabilities {
    switch (this) {
      case PermissionPreset.assignmentOfficer:
        return {
          Capability.contactsViewAll,
          Capability.assignmentsView,
          Capability.assignmentsManage,
          Capability.workersView,
        };
      case PermissionPreset.followUpSupervisor:
        return {
          Capability.contactsViewAll,
          Capability.followupsManageAll,
          Capability.workersView,
        };
      case PermissionPreset.recordsOfficer:
        return {
          Capability.contactsViewAll,
          Capability.contactsEdit,
          Capability.contactsConfirmStatus,
        };
      case PermissionPreset.reportingOfficer:
        return {Capability.reportsViewUnit, Capability.contactsViewAll};
      case PermissionPreset.teamOfficer:
        return {
          Capability.workersView,
          Capability.workersAdd,
          Capability.workersDeactivate,
          Capability.workersManageAvailability,
        };
      case PermissionPreset.deputyManager:
        return Capability.all.difference(Capability.ownerOnly);
      case PermissionPreset.custom:
        return const {};
    }
  }

  bool isAvailableWithin(Set<String> delegablePermissions) {
    if (this == PermissionPreset.custom) return true;
    if (this == PermissionPreset.deputyManager) {
      return delegablePermissions.isNotEmpty;
    }
    return delegablePermissions.containsAll(capabilities);
  }

  Set<String> resolvePermissions(Set<String> delegablePermissions) {
    if (this == PermissionPreset.deputyManager) {
      return Set.unmodifiable(
        delegablePermissions.difference({Capability.permissionsDelegate}),
      );
    }
    if (this == PermissionPreset.custom) return const {};
    return Set.unmodifiable(capabilities);
  }
}
