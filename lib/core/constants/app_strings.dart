/// Centralized String Constants for PCU Workflow
abstract class AppStrings {
  // App Identifiers
  static const String appName = 'Workflow';
  static const String appDisplayName = 'PCU Workflow';
  static const String appTagline = 'Pastoral Care Unit Guest Management';

  // Auth & Roles
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle =
      'Sign in to access your pastoral care workspace';
  static const String emailLabel = 'Email Address';
  static const String passwordLabel = 'Password';
  static const String signInButton = 'Sign In';
  static const String signOutButton = 'Sign Out';

  // Dashboard & Metrics
  static const String metricReceived = 'Received';
  static const String metricContacted = 'Contacted';
  static const String metricRetained = 'Retained';
  static const String metricConverts = 'Converts';
  static const String metricWorkers = 'Became Workers';
  static const String metricContactRate = 'Contact Rate';
  static const String metricRetentionRate = 'Retention Rate';

  // Guest Management
  static const String myGuests = 'My Guests';
  static const String allGuests = 'All Guests';
  static const String guestDetail = 'Guest Details';
  static const String callGuestAction = 'Call Guest';
  static const String addFeedbackAction = 'Add Feedback';
  static const String scheduleFollowUp = 'Schedule Follow-up';

  // Call Outcomes
  static const String outcomeConnected = 'Connected';
  static const String outcomeNoAnswer = 'No Answer';
  static const String outcomeBusy = 'Busy';
  static const String outcomeVoicemail = 'Voicemail';
  static const String outcomeWrongNumber = 'Wrong Number';

  // Errors & States
  static const String genericError = 'Something went wrong. Please try again.';
  static const String noDataAvailable = 'No records found.';
  static const String offlineNotice =
      'You are currently offline. Changes will sync when online.';

  // Organization structure
  static const String manageStructure = 'Manage Structure';
  static const String organizationDetails = 'Organization Details';
  static const String nameLabel = 'Name';
  static const String codeLabel = 'Code';
  static const String saveAction = 'Save';
  static const String addAction = 'Add';
  static const String editAction = 'Edit';
  static const String archiveAction = 'Archive';
  static const String cancelAction = 'Cancel';
  static const String noLocations = 'No active locations yet.';
  static const String noUnits = 'No active units yet.';
  static const String listSeparator = ' \u2022 ';

  // Access delegation
  static const String manageAccess = 'Manage Access';
  static const String manageAccessTooltip = 'Manage unit access';
  static const String accessManagementSubtitle =
      'Appoint assistants and give each person only the access they need.';
  static const String searchTeam = 'Search team members';
  static const String noTeamMembers = 'No active team members yet.';
  static const String noMatchingTeamMembers =
      'No team members match this search.';
  static const String appointAssistant = 'Appoint assistant';
  static const String editAccess = 'Edit access';
  static const String restoreAccess = 'Remove delegated access';
  static const String chooseAccessPreset = 'Choose an access preset';
  static const String customPermissions = 'Custom permissions';
  static const String permissionsLabel = 'Permissions';
  static const String reasonOptional = 'Reason or note (optional)';
  static const String accessUpdated = 'Access updated successfully.';
  static const String previousAccessRestored =
      'Delegated access removed successfully.';
  static const String restoreAccessTitle = 'Remove delegated access?';
  static const String restoreAccessMessage =
      'Existing team members return to their previous access. '
      'Delegation-only memberships are deactivated.';
  static const String updateAccess = 'Update access';
  static const String grantAccess = 'Grant access';
  static const String retryAction = 'Retry';
  static const String loadMoreAction = 'Load more';
  static const String selectPermissionNotice =
      'Select at least one permission.';

  static String capabilityLabel(String capability) {
    switch (capability) {
      case 'contacts.view_all':
        return 'View all contacts';
      case 'contacts.edit':
        return 'Edit contacts';
      case 'contacts.confirm_status':
        return 'Confirm contact status';
      case 'assignments.view':
        return 'View assignments';
      case 'assignments.manage':
        return 'Manage assignments';
      case 'followups.manage_own':
        return 'Manage own follow-ups';
      case 'followups.manage_all':
        return 'Manage all follow-ups';
      case 'workers.view':
        return 'View team';
      case 'workers.add':
        return 'Add team members';
      case 'workers.deactivate':
        return 'Deactivate team members';
      case 'workers.manage_availability':
        return 'Manage availability';
      case 'reports.view_unit':
        return 'View unit reports';
      case 'reports.view_location':
        return 'View location reports';
      case 'reports.view_organization':
        return 'View organization reports';
      case 'permissions.delegate':
        return 'Delegate access';
      case 'audit.view':
        return 'View audit history';
      case 'units.manage':
        return 'Manage units';
      default:
        return capability;
    }
  }
}
