import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../common/insights_cubits.dart';
import '../../common/notifications_cubit.dart';
import '../../common/push_cubit.dart';
import '../../common/session_reset.dart';
import '../../guests/bloc/guests_filter_cubit.dart';
import '../../worker/screens/me_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_team_tab.dart';
import 'admin_guests_tab.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  /// The Guests tab's own month and chip (the Dashboard keeps its own month).
  final _guestsFilter = GuestsFilterCubit();

  @override
  void dispose() {
    _guestsFilter.close();
    super.dispose();
  }

  static const _items = [
    AppNavItem(AppIcons.dashboard, 'Dashboard'),
    AppNavItem(AppIcons.team, 'Team'),
    AppNavItem(AppIcons.guests, 'Guests'),
    AppNavItem(AppIcons.me, 'Me'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().ensureLoaded();
    context.read<PushCubit>().start();
    context.read<NotificationsCubit>().start();
  }

  void _select(int i) {
    if (i == 1) context.read<TeamCubit>().ensureLoaded();
    setState(() => _index = i);
  }

  /// A Dashboard tile opens the list behind its number: that month and chip.
  /// Changing the Dashboard month alone never moves the Guests tab.
  void _openGuests(String chip) {
    _guestsFilter.show(month: context.read<DashboardCubit>().state.month, chip: chip);
    _select(2);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, s) => s is AuthUnauthenticatedState,
      listener: (context, _) {
        resetSessionState(context);
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      },
      child: BlocProvider.value(
        value: _guestsFilter,
        child: Scaffold(
        backgroundColor: AppColors.bg,
        body: FadeIndexedStack(
          index: _index,
          children: [
            AdminDashboardTab(onOpenGuests: _openGuests, onOpenTeam: () => _select(1)),
            const AdminTeamTab(),
            const AdminGuestsTab(),
            const MeTab(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          items: _items,
          currentIndex: _index,
          onTap: _select,
        ),
      ),
      ),
    );
  }
}
