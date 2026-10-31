import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/guest_card_widget.dart';
import '../../../core/widgets/metric_tile_widget.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';

class TodayTab extends StatelessWidget {
  final VoidCallback? onSeeAll;

  const TodayTab({super.key, this.onSeeAll});

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AuthBloc, String>((bloc) {
      final s = bloc.state;
      return s is AuthAuthenticatedState ? s.user.name.split(' ').first : '';
    });
    final now = DateTime.now();

    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        final loaded = state is GuestsLoadedState ? state : null;
        final waiting = loaded?.todayCallCount ?? 0;

        final subtitle = loaded == null
            ? DateFormat('EEEE d MMMM').format(now)
            : waiting == 0
                ? '${DateFormat('EEE d MMM').format(now)} · Everyone has been called'
                : '${DateFormat('EEE d MMM').format(now)} · $waiting ${waiting == 1 ? 'guest' : 'guests'} waiting for a call';

        return Column(
          children: [
            AppHeader(
              title: firstName.isEmpty
                  ? _greeting(now)
                  : '${_greeting(now)}, $firstName',
              subtitle: subtitle,
            ),
            Expanded(child: _body(context, state)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, GuestsState state) {
    final bloc = context.read<GuestsBloc>();

    if (state is GuestsFailureState) {
      return ErrorState(
        message: state.message,
        onRetry: () => bloc.add(const LoadGuestsEvent()),
      );
    }
    if (state is! GuestsLoadedState) {
      return const SkeletonList(withTiles: true);
    }

    final list = state.todayFilteredGuests;
    final String sectionLabel;
    switch (state.tileFilter) {
      case 'call':
        sectionLabel = 'To call';
        break;
      case 'fu':
        sectionLabel = 'Followed up';
        break;
      case 'mem':
        sectionLabel = 'Members';
        break;
      default:
        sectionLabel = 'This month';
    }

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () async {
        bloc.add(LoadGuestsEvent(month: state.selectedMonth));
        await bloc.stream
            .firstWhere((s) => s is! GuestsLoadedState || !s.isRefreshing)
            .timeout(const Duration(seconds: 20), onTimeout: () => state);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            AppSizes.gutter, AppSizes.p16, AppSizes.gutter, AppSizes.p24),
        children: [
          if (state.isFromCache) OfflineBanner(isRefreshing: state.isRefreshing),
          Row(
            children: [
              Expanded(
                child: MetricTileWidget(
                  value: '${state.todayCallCount}',
                  label: 'To call',
                  icon: Icons.call_rounded,
                  iconColor: state.todayCallCount > 0
                      ? AppColors.red
                      : AppColors.subtle,
                  isSelected: state.tileFilter == 'call',
                  onTap: () => bloc.add(const ChangeTileFilterEvent('call')),
                ),
              ),
              SizedBox(width: AppSizes.p8),
              Expanded(
                child: MetricTileWidget(
                  value: '${state.todayFollowedUpCount}',
                  label: 'Followed up',
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.green,
                  isSelected: state.tileFilter == 'fu',
                  onTap: () => bloc.add(const ChangeTileFilterEvent('fu')),
                ),
              ),
              SizedBox(width: AppSizes.p8),
              Expanded(
                child: MetricTileWidget(
                  value: '${state.todayMemberCount}',
                  label: 'Members',
                  icon: Icons.workspace_premium_rounded,
                  iconColor: AppColors.gold,
                  isSelected: state.tileFilter == 'mem',
                  onTap: () => bloc.add(const ChangeTileFilterEvent('mem')),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.p16),
          SectionHeader(
            title: sectionLabel,
            count: list.length,
            actionLabel: state.tileFilter == 'all' ? 'See all' : 'Clear filter',
            onAction: state.tileFilter == 'all'
                ? onSeeAll
                : () => bloc.add(ChangeTileFilterEvent(state.tileFilter)),
          ),
          if (list.isEmpty)
            EmptyState(
              compact: true,
              icon: state.tileFilter == 'call'
                  ? Icons.celebration_rounded
                  : Icons.inbox_rounded,
              title: state.tileFilter == 'call'
                  ? 'All caught up'
                  : 'Nothing here yet',
              message: state.tileFilter == 'call'
                  ? 'Every guest this month has had a call.'
                  : 'Guests assigned to you will show up here.',
            )
          else
            ...list.map(
              (guest) => Padding(
                padding: EdgeInsets.only(bottom: AppSizes.p8),
                child: GuestCardWidget(
                  guest: guest,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.guestDetail,
                    arguments: GuestDetailArgs(guest.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
