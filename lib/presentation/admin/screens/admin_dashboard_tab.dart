import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/state_views.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../../domain/entities/insights.dart';
import '../../../data/firestore/sheet_sync_repository.dart';
import '../../common/insights_cubits.dart';
import '../../common/load_state.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/watch_months.dart';
import '../bloc/sheet_sync_cubit.dart';
import '../../common/notification_bell.dart';
import '../../../data/repositories/assign_repository.dart';
import '../widgets/assign_guests_sheet.dart';
import '../../../domain/attention_rules.dart';
import '../../common/outstanding_button.dart';
import '../widgets/needs_attention_card.dart';
import 'hod_outstanding_screen.dart';
import '../widgets/trend_card.dart';
import '../../common/push_prompt_card.dart';

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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NotificationBell(),
              // Outstanding of every month, by worker: a month change never hides waiting work.
              HodOutstandingBuilder(
                builder: (context, _, workers) => OutstandingButton(
                  count: AttentionRules.total(workers),
                  onTap: () => HodOutstandingScreen.open(context),
                ),
              ),
              SizedBox(width: AppSizes.s4),
              // The Dashboard's own month: it never moves the Guests tab.
              MonthPill(month: state.month, onChanged: cubit.load),
            ],
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

    final page = RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<DashboardCubit>().load(),
      child: PageList(
        children: [
          // Only when the sheet is a day or more behind; otherwise nothing.
          if (AppConfig.useFirestore) const SheetBehindBanner(),
          const PushPromptCard(reason: 'when guests come in and when the sheet sync needs you'),
          UnassignedCard(repo: context.read<IAssignRepository>()),
          if (data.guests == 0 && MonthUtils.isCurrent(data.month))
            EmptyMonthCard(
              month: data.month,
              onPrevious: () => context.read<DashboardCubit>().load(MonthUtils.previous(data.month)),
            ),
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
          NeedsAttentionCard(month: data.month),
          _Journey(month: data.month),
          const TrendCard(),
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
          // Saved work reaches the sheet with the nightly sync or this button.
          if (AppConfig.useFirestore) ...[
            SectionLabel('Sheet'),
            const SheetSyncCard(),
          ],
        ],
      ),
    );
    if (!AppConfig.useFirestore) return page;
    // One sync state for the banner at the top and the Sheet card below.
    return BlocProvider(
      create: (ctx) => SheetSyncCubit(
        ctx.read<ISheetSyncRepository>(),
        onSynced: () {
          ctx.read<DashboardCubit>().load();
          final ranking = ctx.read<RankingCubit>();
          if (ranking.state.data != null) ranking.load();
          final team = ctx.read<TeamCubit>();
          if (team.state.data != null) team.load();
        },
      ),
      child: page,
    );
  }
}

/// Slim gold-outlined banner at the top of the Dashboard when the sheet is a
/// day or more behind, with a Sync now button. Nothing otherwise.
class SheetBehindBanner extends StatelessWidget {
  final DateTime? clock;

  const SheetBehindBanner({super.key, this.clock});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SheetSyncCubit, SheetSyncState>(
      builder: (context, state) {
        final text = state.busy ? null : state.status.behind(clock);
        if (text == null) return const SizedBox.shrink();
        return Container(
          margin: EdgeInsets.only(bottom: AppSizes.s16),
          padding: EdgeInsets.only(left: AppSizes.s16, right: AppSizes.s4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.gold, width: 1.5),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Row(
            children: [
              Icon(AppIcons.sync, size: AppSizes.iconSm, color: AppColors.goldInk),
              SizedBox(width: AppSizes.s8),
              Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.ink))),
              TextButton(
                onPressed: () => context.read<SheetSyncCubit>().syncNow(),
                child: Text('Sync now', style: AppTextStyles.captionStrong.copyWith(color: AppColors.navy)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Early in a month: "No guests yet in November" with last month one tap away.
class EmptyMonthCard extends StatelessWidget {
  final String month;
  final VoidCallback onPrevious;

  const EmptyMonthCard({super.key, required this.month, required this.onPrevious});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.s16),
      child: AppCard(
        child: Row(
          children: [
            Expanded(child: Text('No guests yet in ${MonthUtils.name(month)}.', style: AppTextStyles.bodyMuted)),
            TextButton(
              onPressed: onPrevious,
              child: Text('See ${MonthUtils.name(MonthUtils.previous(month))}',
                  style: AppTextStyles.captionStrong.copyWith(color: AppColors.navy)),
            ),
          ],
        ),
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

/// How the Dashboard month's guests moved along, from the guest cache.
class _Journey extends StatelessWidget {
  final String month;
  const _Journey({required this.month});

  @override
  Widget build(BuildContext context) {
    return WatchMonths(
      months: [month],
      child: BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        final guests = state.guestsOf(month);
        if (guests.isEmpty) return const SizedBox.shrink();
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
    ),
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
          Text(worker.record, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// HOD only: when work last reached the sheet, and the "Sync to sheet" button.
class SheetSyncCard extends StatelessWidget {
  const SheetSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SheetSyncCubit, SheetSyncState>(
      builder: (context, state) {
        // "A day behind" is said by the banner at the top, not twice.
        final warning = state.busy || state.status.behind() != null ? null : state.status.warning();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(AppIcons.sync, size: AppSizes.iconMd, color: AppColors.inkSoft),
                  SizedBox(width: AppSizes.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.status.running && !state.syncing ? 'Syncing...' : state.status.line(),
                          style: AppTextStyles.bodyStrong,
                        ),
                        if (warning != null) ...[
                          SizedBox(height: AppSizes.s4),
                          Text(warning,
                              style: AppTextStyles.caption.copyWith(color: AppColors.amberInk)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.s16),
              AppButton(
                label: state.busy ? 'Syncing...' : 'Sync to sheet',
                icon: AppIcons.sync,
                variant: AppButtonVariant.secondary,
                isLoading: state.syncing,
                onPressed: state.busy ? null : () => context.read<SheetSyncCubit>().syncNow(),
              ),
              if (state.message != null) ...[
                SizedBox(height: AppSizes.s8),
                Text(
                  state.message!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                      color: state.messageIsError ? AppColors.redInk : AppColors.greenInk),
                ),
              ],
              if (state.status.sheetUrl.isNotEmpty)
                Center(
                  child: TextButton(
                    onPressed: () => launchUrl(Uri.parse(state.status.sheetUrl), mode: LaunchMode.externalApplication),
                    child: Text('Open the sheet', style: AppTextStyles.captionStrong.copyWith(color: AppColors.navy)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
