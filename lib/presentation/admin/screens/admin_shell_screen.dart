import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../common/insights_cubits.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
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
  }

  void _select(int i) {
    if (i == 1) context.read<TeamCubit>().ensureLoaded();
    setState(() => _index = i);
  }

  void _openGuests(String chip) {
    context.read<GuestsBloc>().add(ChangeChipFilterEvent(chip));
    _select(2);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, s) => s is AuthUnauthenticatedState,
      listener: (context, _) => Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
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
    );
  }
}
