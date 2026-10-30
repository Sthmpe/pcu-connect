/// Central registry of named route strings. No magic strings elsewhere.
abstract class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String guests = '/guests';
  static const String guestDetail = '/guests/detail';
  static const String callFeedback = '/call-feedback';
  static const String followUps = '/follow-ups';
  static const String reports = '/reports';
  static const String team = '/team';
  static const String profile = '/profile';
  static const String organizationStructure = '/organization-structure';
  static const String delegation = '/access/delegation';
}

class DelegationRouteArguments {
  final String unitId;
  final String unitName;

  const DelegationRouteArguments({
    required this.unitId,
    required this.unitName,
  });
}
