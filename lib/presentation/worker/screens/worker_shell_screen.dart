import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import 'today_tab.dart';
import 'my_guests_tab.dart';
import 'ranking_tab.dart';
import 'me_tab.dart';

class WorkerShellScreen extends StatefulWidget {
  const WorkerShellScreen({super.key});

  @override
  State<WorkerShellScreen> createState() => _WorkerShellScreenState();
}

class _WorkerShellScreenState extends State<WorkerShellScreen> {
  int _currentTabIndex = 0;

  static const _items = [
    AppNavItem(Icons.today_outlined, Icons.today_rounded, 'Today'),
    AppNavItem(Icons.people_outline_rounded, Icons.people_rounded, 'Guests'),
    AppNavItem(Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Ranking'),
    AppNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
  ];

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
            TodayTab(onSeeAll: () => setState(() => _currentTabIndex = 1)),
            const MyGuestsTab(),
            const RankingTab(),
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
