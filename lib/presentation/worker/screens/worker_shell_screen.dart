import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../common/notifications_cubit.dart';
import '../../common/session_reset.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_filter_cubit.dart';
import '../../../core/config/app_config.dart';
import '../../../data/firestore/worker_calls_repository.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import '../bloc/today_cubit.dart';
import '../widgets/call_outcome_sheet.dart';
import '../../common/push_cubit.dart';
import 'today_tab.dart';
import 'my_guests_tab.dart';
import 'ranking_tab.dart';
import 'me_tab.dart';

class WorkerShellScreen extends StatefulWidget {
  /// The worker's Guests screen opens on All months, so no guest is out of view.
  static const guestsDefaultMonth = MonthUtils.all;

  const WorkerShellScreen({super.key});

  @override
  State<WorkerShellScreen> createState() => _WorkerShellScreenState();
}

class _WorkerShellScreenState extends State<WorkerShellScreen> {
  int _index = 0;

  /// The Guests tab's own month and chip. Today follows no month at all.
  final _guestsFilter = GuestsFilterCubit(month: WorkerShellScreen.guestsDefaultMonth);

  /// Today's to-do list, shared by the Today tab and its badge.
  late final TodayCubit _today;

  @override
  void dispose() {
    _guestsFilter.close();
    _today.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context.read<PushCubit>().start();
    context.read<NotificationsCubit>().start();
    final auth = context.read<IAuthRepository>();
    _today = TodayCubit(
      guests: context.read<GuestsBloc>(),
      calls: context.read<IWorkerCallsRepository>(),
      worker: () => (auth.currentUser?.email ?? '').trim().toLowerCase(),
      since: AppConfig.chaseFrom,
    )..start();
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
        resetSessionState(context);
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _guestsFilter),
          BlocProvider.value(value: _today),
        ],
        // Coming back from a call or WhatsApp asks how it went.
        child: CallReturnPrompt(
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
            // The Today tab shows how many guests need action, live.
            bottomNavigationBar: BlocBuilder<TodayCubit, TodayState>(
              bloc: _today,
              buildWhen: (a, b) => a.view.total != b.view.total || a.view.outstanding.length != b.view.outstanding.length,
              builder: (context, today) => AppBottomNav(
                items: [
                  AppNavItem(_items[0].icon, _items[0].label, badge: today.loading ? 0 : today.view.total),
                  // Guests: outstanding guests, a red count with soft ripples.
              AppNavItem(_items[1].icon, _items[1].label, alert: today.loading ? 0 : today.view.outstanding.length),
              ..._items.skip(2),
                ],
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
