import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/guests/bloc/guests_filter_cubit.dart';
import '../../presentation/common/notifications_screen.dart';
import '../../presentation/admin/screens/add_worker_screen.dart';
import '../../presentation/admin/screens/admin_guests_tab.dart';
import '../../presentation/admin/screens/admin_shell_screen.dart';
import '../../presentation/admin/screens/message_templates_screen.dart';
import '../../presentation/admin/screens/worker_detail_screen.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/worker/screens/guest_detail_screen.dart';
import '../../presentation/worker/screens/log_follow_up_screen.dart';
import '../../presentation/worker/screens/worker_shell_screen.dart';

/// Named routes for the whole app.
abstract class AppRoutes {
  static const String login = '/';
  static const String worker = '/worker';
  static const String guestDetail = '/guest';
  static const String logFollowUp = '/guest/log';
  static const String admin = '/admin';
  static const String workerDetail = '/admin/worker';
  static const String addWorker = '/admin/worker/new';
  static const String workerGuests = '/admin/worker/guests';
  static const String notifications = '/notifications';
  static const String messageTemplates = '/admin/messages';

  /// The app always starts on the sign-in screen, which restores the session
  /// and routes by role. A refreshed deep link therefore cannot open a screen
  /// before the user is known.
  static List<Route<dynamic>> initialRoutes(String _) => [
        MaterialPageRoute(
          settings: const RouteSettings(name: login),
          builder: (_) => const LoginScreen(),
        ),
      ];

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    Widget page;

    switch (settings.name) {
      case worker:
        page = const WorkerShellScreen();
        break;
      case admin:
        page = const AdminShellScreen();
        break;
      case guestDetail when args is GuestDetailArgs:
        page = GuestDetailScreen(guestId: args.guestId, asAdmin: args.asAdmin);
        break;
      case logFollowUp when args is LogFollowUpArgs:
        page = LogFollowUpScreen(
          guestId: args.guestId,
          initialOutcome: args.initialOutcome,
        );
        break;
      case workerDetail when args is String:
        page = WorkerDetailScreen(workerId: args);
        break;
      case addWorker:
        page = const AddWorkerScreen();
        break;
      case workerGuests when args is String:
        // Its own month and chip, separate from the HOD's Guests tab.
        page = BlocProvider(create: (_) => GuestsFilterCubit(), child: AdminGuestsTab(workerFilter: args));
        break;
      case notifications:
        page = const NotificationsScreen();
        break;
      case messageTemplates:
        page = const MessageTemplatesScreen();
        break;
      default:
        page = const LoginScreen();
    }

    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }
}

class GuestDetailArgs {
  final String guestId;
  final bool asAdmin;

  const GuestDetailArgs(this.guestId, {this.asAdmin = false});
}

class LogFollowUpArgs {
  final String guestId;
  final String? initialOutcome;

  const LogFollowUpArgs(this.guestId, {this.initialOutcome});
}
