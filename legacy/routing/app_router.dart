import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/access_control/data/repositories/access_control_repository_impl.dart';
import '../../features/access_control/presentation/bloc/delegation_bloc.dart';
import '../../features/access_control/presentation/screens/delegation_screen.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/call_workflow/data/repositories/call_repository_impl.dart';
import '../../features/call_workflow/presentation/bloc/call_bloc.dart';
import '../../features/call_workflow/presentation/screens/call_feedback_screen.dart';
import '../../features/guests/data/repositories/guest_repository_impl.dart';
import '../../features/guests/domain/models/guest_model.dart';
import '../../features/guests/presentation/bloc/guest_bloc.dart';
import '../../features/guests/presentation/screens/guest_detail_screen.dart';
import '../../features/guests/presentation/screens/my_guests_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/organization_structure/data/repositories/organization_structure_repository_impl.dart';
import '../../features/organization_structure/presentation/bloc/organization_structure_bloc.dart';
import '../../features/organization_structure/presentation/screens/organization_structure_screen.dart';
import 'app_routes.dart';

/// Primary navigation is plain Material `onGenerateRoute` - explicit,
/// debuggable, no reflection/magic. GetX is reserved for isolated,
/// genuinely complex flows (e.g. nested reassignment wizards) only,
/// invoked locally within that feature - never as the app-wide router.
///
/// Feature blocs (Guests, Call) are created fresh per route here rather
/// than held app-wide, so each screen gets a clean bloc instance - no
/// stale state leaking between the guest list and guest detail, and
/// the bloc is disposed the moment its screen is popped.
class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _page(const SplashScreen(), settings);
      case AppRoutes.login:
        return _page(const LoginScreen(), settings);
      case AppRoutes.home:
        return _page(const HomeScreen(), settings);
      case AppRoutes.organizationStructure:
        final organizationId = settings.arguments as String;
        return _page(
          BlocProvider(
            create: (_) => OrganizationStructureBloc(
              repository: OrganizationStructureRepositoryImpl(),
            ),
            child: OrganizationStructureScreen(organizationId: organizationId),
          ),
          settings,
        );
      case AppRoutes.delegation:
        final arguments = settings.arguments as DelegationRouteArguments;
        return _page(
          BlocProvider(
            create: (_) =>
                DelegationBloc(repository: AccessControlRepositoryImpl()),
            child: DelegationScreen(
              unitId: arguments.unitId,
              unitName: arguments.unitName,
            ),
          ),
          settings,
        );
      case AppRoutes.guests:
        return _page(
          BlocProvider(
            create: (_) => GuestBloc(guestRepository: GuestRepositoryImpl()),
            child: const MyGuestsScreen(),
          ),
          settings,
        );
      case AppRoutes.guestDetail:
        final guestId = settings.arguments as String;
        return _page(
          BlocProvider(
            create: (_) => GuestBloc(guestRepository: GuestRepositoryImpl()),
            child: GuestDetailScreen(guestId: guestId),
          ),
          settings,
        );
      case AppRoutes.callFeedback:
        final guest = settings.arguments as GuestModel;
        return _page(
          BlocProvider(
            create: (_) => CallBloc(callRepository: CallRepositoryImpl()),
            child: CallFeedbackScreen(guest: guest),
          ),
          settings,
        );
      default:
        return _page(
          Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          settings,
        );
    }
  }

  static MaterialPageRoute<dynamic> _page(
    Widget child,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(builder: (_) => child, settings: settings);
  }
}
