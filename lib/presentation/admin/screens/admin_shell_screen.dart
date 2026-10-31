import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
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
  int _currentTabIndex = 0;

  static const _items = [
    AppNavItem(Icons.insights_outlined, Icons.insights_rounded, 'Dashboard'),
    AppNavItem(Icons.badge_outlined, Icons.badge_rounded, 'Team'),
    AppNavItem(Icons.people_outline_rounded, Icons.people_rounded, 'Guests'),
    AppNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
  ];

  void _openGuests(String chip) {
    context.read<GuestsBloc>().add(ChangeChipFilterEvent(chip));
    setState(() => _currentTabIndex = 2);
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
          index: _currentTabIndex,
          children: [
            AdminDashboardTab(
              onOpenGuests: _openGuests,
              onOpenTeam: () => setState(() => _currentTabIndex = 1),
            ),
            const AdminTeamTab(),
            const AdminGuestsTab(),
            const MeTab(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          items: _items,
          currentIndex: _currentTabIndex,
          onTap: (i) => setState(() => _currentTabIndex = i),
        ),
      ),
    );
  }
}
