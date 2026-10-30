/// Every capability the platform knows about. Authorization is capability
/// based, not role based - a role only sets the maximum a user *could* be
/// granted, actual access is whatever capabilities their membership holds.
///
/// Kept as plain string constants (not an enum) so new capabilities can be
/// added without a breaking Firestore data migration - documents already
/// store the string keys.
abstract class Capability {
  // Organization / structure management (organization_owner territory)
  static const organizationManage = 'organization.manage';
  static const locationsManage = 'locations.manage';
  static const unitsManage = 'units.manage';
  static const managersManage = 'managers.manage';

  // Contacts (guests)
  static const contactsViewAll = 'contacts.view_all';
  static const contactsEdit = 'contacts.edit';
  static const contactsConfirmStatus = 'contacts.confirm_status';

  // Assignments
  static const assignmentsView = 'assignments.view';
  static const assignmentsManage = 'assignments.manage';

  // Follow-ups
  static const followupsManageOwn = 'followups.manage_own';
  static const followupsManageAll = 'followups.manage_all';

  // Workers (operators)
  static const workersView = 'workers.view';
  static const workersAdd = 'workers.add';
  static const workersDeactivate = 'workers.deactivate';
  static const workersManageAvailability = 'workers.manage_availability';

  // Reporting
  static const reportsViewUnit = 'reports.view_unit';
  static const reportsViewLocation = 'reports.view_location';
  static const reportsViewOrganization = 'reports.view_organization';

  // Delegation / governance
  static const permissionsDelegate = 'permissions.delegate';
  static const auditView = 'audit.view';

  static const all = <String>{
    organizationManage,
    locationsManage,
    unitsManage,
    managersManage,
    contactsViewAll,
    contactsEdit,
    contactsConfirmStatus,
    assignmentsView,
    assignmentsManage,
    followupsManageOwn,
    followupsManageAll,
    workersView,
    workersAdd,
    workersDeactivate,
    workersManageAvailability,
    reportsViewUnit,
    reportsViewLocation,
    reportsViewOrganization,
    permissionsDelegate,
    auditView,
  };

  /// Capabilities an organization_owner (Pastor) may never delegate away,
  /// even to a Deputy / co-manager. Enforced server-side in manage-access.
  static const ownerOnly = <String>{
    organizationManage,
    locationsManage,
    managersManage,
  };
}

/// The hierarchy ceiling. This bounds what a role *could* hold; the
/// membership's `permissions` map is what it *actually* holds.
enum BaseRole {
  organizationOwner, // Pastor
  unitManager, // HOD
  delegate, // Assignment/Records/Reporting Officer, Deputy HOD, etc.
  operator, // Worker
  viewer; // Pastor-appointed or org-wide read-only viewer

  static BaseRole fromString(String value) {
    switch (value) {
      case 'organization_owner':
        return BaseRole.organizationOwner;
      case 'unit_manager':
        return BaseRole.unitManager;
      case 'delegate':
        return BaseRole.delegate;
      case 'viewer':
        return BaseRole.viewer;
      default:
        return BaseRole.operator;
    }
  }

  String get wireValue {
    switch (this) {
      case BaseRole.organizationOwner:
        return 'organization_owner';
      case BaseRole.unitManager:
        return 'unit_manager';
      case BaseRole.delegate:
        return 'delegate';
      case BaseRole.viewer:
        return 'viewer';
      case BaseRole.operator:
        return 'operator';
    }
  }
}
