import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../common/notifications_cubit.dart';
import '../../common/push_cubit.dart';
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
  int _index = 0;

  @override
  void initState() {
    super.initState();
    context.read<PushCubit>().start();
    context.read<NotificationsCubit>().start();
  }

  static const _items = [
    AppNavItem(AppIcons.today, 'Today'),
    AppNavItem(AppIcons.guests, 'Guests'),
    AppNavItem(AppIcons.ranking, 'Ranking'),
    AppNavItem(AppIcons.me, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, s) => s is AuthUnauthenticatedState,
      listener: (context, _) {
        context.read<NotificationsCubit>().stop();
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: FadeIndexedStack(
          index: _index,
          children: [
            TodayTab(onSeeAll: () => setState(() => _index = 1)),
            const MyGuestsTab(),
            RankingTab(active: _index == 2),
            const MeTab(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          items: _items,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
