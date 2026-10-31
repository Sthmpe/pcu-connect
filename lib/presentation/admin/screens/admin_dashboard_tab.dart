import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/filter_chip_widget.dart';
import '../../../core/widgets/metric_tile_widget.dart';
import '../../../core/widgets/month_sheet.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';
import '../cubit/team_cubit.dart';

class AdminDashboardTab extends StatelessWidget {
  final ValueChanged<String> onOpenGuests;
  final VoidCallback onOpenTeam;

  const AdminDashboardTab({
    super.key,
    required this.onOpenGuests,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GuestsBloc>();

    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        final loaded = state is GuestsLoadedState ? state : null;
        final month = loaded?.selectedMonth ?? kAppMonths.first;

        return Column(
          children: [
            AppHeader(
              title: 'Dashboard',
              subtitle: '$month · Guests who came this month',
            ),
            if (loaded != null)
              ChipBar(
                chips: [
                  for (final m in kAppMonths)
                    FilterChipWidget(
                      label: shortMonth(m),
                      isSelected: m == month,
                      onTap: () => bloc.add(SelectMonthEvent(m)),
                    ),
                ],
              ),
            Expanded(
              child: state is GuestsFailureState
                  ? ErrorState(
                      message: state.message,
                      onRetry: () => bloc.add(const LoadGuestsEvent()),
                    )
                  : loaded == null
                      ? const SkeletonList(count: 3, withTiles: true)
                      : _DashboardBody(
                          state: loaded,
                          onOpenGuests: onOpenGuests,
                          onOpenTeam: onOpenTeam,
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final GuestsLoadedState state;
  final ValueChanged<String> onOpenGuests;
  final VoidCallback onOpenTeam;

  const _DashboardBody({
    required this.state,
    required this.onOpenGuests,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final guests =
        state.allGuests.where((g) => g.month == state.selectedMonth).toList();
    final total = guests.length;
    final called = guests.where((g) => g.callCount > 0).length;
    final notCalled = total - called;
    final members = guests.where((g) => g.status == 'Member').length;
    final inTeam = guests.where((g) => g.teamJoined.isNotEmpty).length;
    final followedTwice = guests.where((g) => g.callCount >= 2).length;
    final cameSunday = guests.where((g) => g.sundayAttendance > 0).length;
    final cameWednesday = guests.where((g) => g.wednesdayAttendance > 0).length;
    final calledPct = total == 0 ? 0.0 : called / total;

    final topWorkers = context
        .watch<TeamCubit>()
        .ranked
        .where((w) => w.active && w.role == 'Worker')
        .take(3)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSizes.gutter, AppSizes.p16, AppSizes.gutter, AppSizes.p24),
      children: [
        if (state.isFromCache) OfflineBanner(isRefreshing: state.isRefreshing),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Guests called', style: AppTextStyles.cardTitle),
                        SizedBox(height: AppSizes.p2),
                        Text('$called of $total guests have had a call',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Text(
                    '${(calledPct * 100).round()}%',
                    style: AppTextStyles.numberLg.copyWith(
                      color: calledPct >= 0.8
                          ? AppColors.greenInk
                          : calledPct >= 0.5
                              ? AppColors.amberInk
                              : AppColors.redInk,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.p12),
              AppProgressBar(
                value: calledPct,
                height: AppSizes.p8,
                color: calledPct >= 0.8
                    ? AppColors.green
                    : calledPct >= 0.5
                        ? AppColors.amber
                        : AppColors.red,
              ),
            ],
          ),
        ),
        SizedBox(height: AppSizes.p12),
        Row(
          children: [
            Expanded(
              child: MetricTileWidget(
                value: '$total',
                label: 'Guests',
                icon: Icons.people_rounded,
                iconColor: AppColors.navy,
                onTap: () => onOpenGuests('all'),
              ),
            ),
            SizedBox(width: AppSizes.p8),
            Expanded(
              child: MetricTileWidget(
                value: '$notCalled',
                label: 'Not called',
                valueColor: notCalled > 0 ? AppColors.redInk : AppColors.ink,
                icon: Icons.phone_missed_rounded,
                iconColor: AppColors.red,
                onTap: () => onOpenGuests('call'),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSizes.p8),
        Row(
          children: [
            Expanded(
              child: MetricTileWidget(
                value: '$members',
                label: 'Members',
                valueColor: AppColors.goldInk,
                icon: Icons.workspace_premium_rounded,
                iconColor: AppColors.gold,
                onTap: () => onOpenGuests('mem'),
              ),
            ),
            SizedBox(width: AppSizes.p8),
            Expanded(
              child: MetricTileWidget(
                value: '$inTeam',
                label: 'In a team',
                valueColor: AppColors.blueInk,
                icon: Icons.groups_rounded,
                iconColor: AppColors.blue,
                onTap: () => onOpenGuests('team'),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSizes.p16),
        const SectionHeader(title: 'Retention funnel'),
        AppCard(
          child: Column(
            children: [
              _FunnelRow('Called', called, total, AppColors.navy),
              _FunnelRow('Followed up 2+ times', followedTwice, total, AppColors.navy),
              _FunnelRow('Came on a Sunday', cameSunday, total, AppColors.blue),
              _FunnelRow('Came on a Wednesday', cameWednesday, total, AppColors.blue),
              _FunnelRow('Became members', members, total, AppColors.gold, last: true),
            ],
          ),
        ),
        SizedBox(height: AppSizes.p16),
        SectionHeader(
          title: 'Top workers',
          actionLabel: 'See team',
          onAction: onOpenTeam,
        ),
        if (topWorkers.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.badge_outlined,
            title: 'No active workers',
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < topWorkers.length; i++) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.workerDetail,
                      arguments: topWorkers[i].id,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.p16),
                    leading: SizedBox(
                      width: AppSizes.p32 + AppSizes.avatarSm,
                      child: Row(
                        children: [
                          SizedBox(
                            width: AppSizes.p20,
                            child: Text('${i + 1}',
                                style: AppTextStyles.secondaryStrong),
                          ),
                          AppAvatar(
                            initials: initialsOf(topWorkers[i].name),
                            size: AppSizes.avatarSm,
                            background: i == 0 ? AppColors.goldSoft : AppColors.navySoft,
                            foreground: i == 0 ? AppColors.goldInk : AppColors.navy,
                          ),
                        ],
                      ),
                    ),
                    title: Text(topWorkers[i].name, style: AppTextStyles.itemTitle),
                    trailing: Text(
                      '${topWorkers[i].members} ${topWorkers[i].members == 1 ? 'member' : 'members'}',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _FunnelRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  final bool last;

  const _FunnelRow(this.label, this.value, this.total, this.color,
      {this.last = false});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSizes.p12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.secondaryStrong)),
              Text('$value', style: AppTextStyles.captionStrong),
              SizedBox(width: AppSizes.p6),
              SizedBox(
                width: AppSizes.p32 + AppSizes.p4,
                child: Text('${(pct * 100).round()}%',
                    textAlign: TextAlign.right, style: AppTextStyles.caption),
              ),
            ],
          ),
          SizedBox(height: AppSizes.p6),
          AppProgressBar(value: pct, color: color),
        ],
      ),
    );
  }
}
