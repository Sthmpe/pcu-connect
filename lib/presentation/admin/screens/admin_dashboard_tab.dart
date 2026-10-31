import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/state_views.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../../domain/entities/insights.dart';
import '../../common/insights_cubits.dart';
import '../../common/load_state.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';

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
    final cubit = context.read<DashboardCubit>();
    return BlocBuilder<DashboardCubit, LoadState<DashboardSummary>>(
      builder: (context, state) {
        return AppPage(
          title: 'Dashboard',
          trailing: MonthPill(
            month: state.month,
            onChanged: (m) {
              cubit.load(m);
              context.read<GuestsBloc>().add(SelectMonthEvent(m));
            },
          ),
          child: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, LoadState<DashboardSummary> state) {
    final data = state.data;
    if (data == null) {
      if (state.status == LoadStatus.failure) {
        return ErrorState(
          message: state.message ?? '',
          onRetry: () => context.read<DashboardCubit>().load(),
        );
      }
      return const SkeletonPage(hero: true, rows: 3);
    }

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<DashboardCubit>().load(),
      child: PageList(
        children: [
          _CalledHero(data: data, onSeeWaiting: () => onOpenGuests('call')),
          SizedBox(height: AppSizes.s16),
          StatGrid(items: [
            StatItem('${data.guests}', 'Guests', onTap: () => onOpenGuests('all')),
            StatItem('${data.notCalled}', 'Not called yet',
                color: data.notCalled > 0 ? AppColors.redInk : null,
                onTap: () => onOpenGuests('call')),
            StatItem('${data.members}', 'Became members', onTap: () => onOpenGuests('mem')),
            StatItem('${data.inTeam}', 'Joined a team', onTap: () => onOpenGuests('team')),
          ]),
          const _Journey(),
          SectionLabel('Top workers', actionLabel: 'See team', onAction: onOpenTeam),
          if (data.topWorkers.isEmpty)
            AppCard(
              child: Text('No points logged yet this month.', style: AppTextStyles.bodyMuted),
            )
          else
            GroupedCard(
              dividerIndent: AppSizes.s16 * 3 + AppSizes.s8 + AppSizes.avatarSm,
              children: [
                for (var i = 0; i < data.topWorkers.length; i++)
                  _TopWorkerRow(rank: i + 1, worker: data.topWorkers[i]),
              ],
            ),
        ],
      ),
    );
  }
}

class _CalledHero extends StatelessWidget {
  final DashboardSummary data;
  final VoidCallback onSeeWaiting;

  const _CalledHero({required this.data, required this.onSeeWaiting});

  @override
  Widget build(BuildContext context) {
    final waiting = data.notCalled;
    return AppCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.navyRaised, AppColors.navy],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: data.calledRate,
                size: 72,
                stroke: 6,
                color: AppColors.onNavy,
                trackColor: AppColors.onNavy.withValues(alpha: 0.14),
                child: Text('${(data.calledRate * 100).round()}%',
                    style: AppTextStyles.bodyStrong.copyWith(color: AppColors.onNavy)),
              ),
              SizedBox(width: AppSizes.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.guests == 0
                          ? 'No guests yet'
                          : '${data.called} of ${data.guests} guests called',
                      style: AppTextStyles.title.copyWith(color: AppColors.onNavy),
                    ),
                    SizedBox(height: AppSizes.s4),
                    Text(
                      waiting == 0
                          ? 'Everyone in ${MonthUtils.name(data.month)} has had a call'
                          : '$waiting still ${waiting == 1 ? 'waits' : 'wait'} for a first call',
                      style: AppTextStyles.caption.copyWith(color: AppColors.onNavyMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (waiting > 0) ...[
            SizedBox(height: AppSizes.s24),
            AppButton(
              label: 'See who is waiting',
              icon: AppIcons.call,
              onPressed: onSeeWaiting,
            ),
          ],
        ],
      ),
    );
  }
}

/// How this month's guests moved along, from the loaded guest list.
class _Journey extends StatelessWidget {
  const _Journey();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        if (state is! GuestsLoadedState || state.monthGuests.isEmpty) {
          return const SizedBox.shrink();
        }
        final guests = state.monthGuests;
        final total = guests.length;
        int count(bool Function(GuestEntity g) test) => guests.where(test).length;
        final steps = [
          ('Called', count((g) => g.callCount > 0), AppColors.navy),
          ('Followed up twice', count((g) => g.callCount >= 2), AppColors.navy),
          ('Came back to church',
              count((g) => g.sundayAttendance + g.wednesdayAttendance > 0), AppColors.blue),
          ('Became members', count((g) => g.status == 'Member'), AppColors.green),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel('Guest journey'),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) SizedBox(height: AppSizes.s16),
                    Row(
                      children: [
                        Expanded(child: Text(steps[i].$1, style: AppTextStyles.body)),
                        Text('${steps[i].$2} of $total', style: AppTextStyles.caption),
                      ],
                    ),
                    SizedBox(height: AppSizes.s8),
                    AppProgressBar(value: steps[i].$2 / total, color: steps[i].$3),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopWorkerRow extends StatelessWidget {
  final int rank;
  final TopWorker worker;

  const _TopWorkerRow({required this.rank, required this.worker});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: AppSizes.touch + AppSizes.s8),
      padding: EdgeInsets.symmetric(horizontal: AppSizes.s16),
      child: Row(
        children: [
          SizedBox(width: AppSizes.s16, child: Text('$rank', style: AppTextStyles.caption)),
          SizedBox(width: AppSizes.s8),
          AppAvatar(name: worker.name, size: AppSizes.avatarSm),
          SizedBox(width: AppSizes.s16),
          Expanded(child: Text(worker.name, style: AppTextStyles.body)),
          Text(
            '${worker.members} ${worker.members == 1 ? 'member' : 'members'}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
