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
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/insights.dart';
import '../../common/insights_cubits.dart';
import '../../common/load_state.dart';

class RankingTab extends StatefulWidget {
  /// Loads the first time the tab becomes visible.
  final bool active;

  const RankingTab({super.key, this.active = false});

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  @override
  void didUpdateWidget(RankingTab old) {
    super.didUpdateWidget(old);
    if (widget.active) context.read<RankingCubit>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RankingCubit>();
    return BlocBuilder<RankingCubit, LoadState<RankingView>>(
      builder: (context, state) {
        return AppPage(
          title: 'Ranking',
          trailing: AppIconButton(
            icon: AppIcons.info,
            tooltip: 'How points work',
            background: Colors.transparent,
            onTap: () => showPointsSheet(context),
          ),
          below: ChipBar(
            chips: [
              for (final m in MonthUtils.recent(6))
                AppChip(
                  label: MonthUtils.chip(m),
                  selected: m == state.month,
                  onTap: () => cubit.load(m),
                ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppDurations.normal,
            child: KeyedSubtree(
              key: ValueKey('${state.month}-${state.data != null}'),
              child: _body(context, state),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, LoadState<RankingView> state) {
    final view = state.data;
    final loadingOtherMonth = state.isLoading && view?.ranking.month != state.month;
    if (view == null || loadingOtherMonth) {
      if (state.status == LoadStatus.failure) {
        return ErrorState(
          message: state.message ?? '',
          onRetry: () => context.read<RankingCubit>().load(),
        );
      }
      return const SkeletonPage(hero: true, rows: 4);
    }

    final ranking = view.ranking;
    final isPast = !MonthUtils.isCurrent(state.month);
    final monthName = MonthUtils.name(state.month);

    if (ranking.entries.isEmpty) {
      return Center(
        child: EmptyState(
          icon: AppIcons.ranking,
          message: 'No one was ranked in $monthName.',
          actionLabel: 'How points work',
          onAction: () => showPointsSheet(context),
        ),
      );
    }

    final me = ranking.me;
    final anyPoints = ranking.entries.first.points > 0;
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<RankingCubit>().load(),
      child: PageList(
        children: [
          if (anyPoints)
            _TopThree(entries: ranking.entries.take(3).toList(), meEmail: me?.email)
          else
            AppCard(
              child: Text(
                isPast
                    ? 'No points were earned in $monthName.'
                    : 'No points yet this month. The first follow-up starts the board.',
                style: AppTextStyles.bodyMuted,
              ),
            ),
          if (me != null && anyPoints) ...[
            SizedBox(height: AppSizes.s16),
            _MyPosition(me: me, entries: ranking.entries, isPast: isPast),
          ],
          SectionLabel(isPast ? 'Final standings, $monthName' : 'Standings so far'),
          GroupedCard(
            dividerIndent: AppSizes.s16 + AppSizes.s24 + AppSizes.s16 + AppSizes.avatarSm,
            children: [
              for (final e in ranking.entries)
                RankRow(
                  entry: e,
                  isMe: e.email == me?.email,
                  movement: view.movement(e),
                ),
            ],
          ),
          if (ranking.entries.any((e) => (view.movement(e) ?? 0) != 0)) ...[
            SizedBox(height: AppSizes.s8),
            Text(
              'Arrows compare with ${MonthUtils.name(MonthUtils.previous(state.month))}.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopThree extends StatelessWidget {
  final List<RankingEntry> entries;
  final String? meEmail;

  const _TopThree({required this.entries, this.meEmail});

  @override
  Widget build(BuildContext context) {
    const badges = [AppColors.gold, AppColors.silver, AppColors.bronze];
    // Second, first, third, with first slightly raised.
    const order = [1, 0, 2];

    return AppCard(
      padding: EdgeInsets.symmetric(vertical: AppSizes.s24, horizontal: AppSizes.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final i in order)
            Expanded(
              child: i >= entries.length
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(bottom: i == 0 ? AppSizes.s16 : 0),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AppAvatar(
                                name: entries[i].name,
                                size: i == 0 ? AppSizes.avatarLg : AppSizes.s48,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: badges[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.surface, width: 2),
                                  ),
                                  child: Text(
                                    '${entries[i].rank}',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.centered(AppTextStyles.captionStrong).copyWith(
                                      color: i == 0 ? AppColors.navy : AppColors.onNavy,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppSizes.s16),
                          Text(
                            entries[i].email == meEmail ? 'You' : firstNameOf(entries[i].name),
                            style: AppTextStyles.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppSizes.s4 / 2),
                          Text('${entries[i].points} pts', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

class _MyPosition extends StatelessWidget {
  final RankingEntry me;
  final List<RankingEntry> entries;
  final bool isPast;

  const _MyPosition({required this.me, required this.entries, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final ahead = entries.where((e) => e.points > me.points).toList();
    final String headline = isPast
        ? 'You finished ${_ordinal(me.rank)} with ${me.points} points'
        : 'You are ${_ordinal(me.rank)} with ${me.points} points';
    final String line;
    if (me.rank == 1) {
      line = isPast ? 'Top of the team. Well done.' : 'You lead this month. Well done.';
    } else if (isPast) {
      line = 'Thank you for every call.';
    } else if (ahead.isNotEmpty) {
      final gap = ahead.last.points - me.points;
      line = '$gap ${gap == 1 ? 'point' : 'points'} to move up';
    } else {
      line = 'Keep going.';
    }

    return Container(
      padding: EdgeInsets.all(AppSizes.s16),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Icon(AppIcons.award, size: AppSizes.iconLg, color: AppColors.goldInk),
          SizedBox(width: AppSizes.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: AppTextStyles.bodyStrong.copyWith(color: AppColors.goldInk)),
                SizedBox(height: AppSizes.s4 / 2),
                Text(line, style: AppTextStyles.caption.copyWith(color: AppColors.goldInk)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed-in worker's own row gets a soft gold highlight when they are
/// outside the top three (the podium already shows the top three).
bool rankRowHighlighted(RankingEntry entry, {required bool isMe}) => isMe && entry.rank > 3;

class RankRow extends StatelessWidget {
  final RankingEntry entry;
  final bool isMe;
  final int? movement;

  const RankRow({super.key, required this.entry, required this.isMe, this.movement});

  @override
  Widget build(BuildContext context) {
    final highlight = rankRowHighlighted(entry, isMe: isMe);
    return Container(
      color: highlight ? AppColors.goldSoft : null,
      constraints: BoxConstraints(minHeight: AppSizes.touch + AppSizes.s8),
      padding: EdgeInsets.symmetric(horizontal: AppSizes.s16),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.s24,
            child: Text('${entry.rank}',
                style: highlight ? AppTextStyles.captionStrong.copyWith(color: AppColors.goldInk) : AppTextStyles.caption),
          ),
          SizedBox(width: AppSizes.s16),
          AppAvatar(name: entry.name, size: AppSizes.avatarSm),
          SizedBox(width: AppSizes.s16),
          Expanded(
            child: Text(isMe ? 'You' : entry.name,
                style: isMe ? AppTextStyles.bodyStrong : AppTextStyles.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          _Movement(movement),
          SizedBox(width: AppSizes.s8),
          SizedBox(
            width: 64,
            child: Text('${entry.points} pts',
                textAlign: TextAlign.right, style: AppTextStyles.bodyStrong),
          ),
        ],
      ),
    );
  }
}

/// Small up or down marker against last month. Nothing when unchanged or new.
class _Movement extends StatelessWidget {
  final int? places;

  const _Movement(this.places);

  @override
  Widget build(BuildContext context) {
    final p = places;
    if (p == null || p == 0) return const SizedBox(width: 32);
    final up = p > 0;
    final color = up ? AppColors.greenInk : AppColors.redInk;
    return Tooltip(
      message: up ? 'Up $p since last month' : 'Down ${-p} since last month',
      child: SizedBox(
        width: 32,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(up ? AppIcons.up : AppIcons.down, size: 12, color: color),
            Text('${p.abs()}', style: AppTextStyles.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Short explainer of the points rules.
Future<void> showPointsSheet(BuildContext context) {
  const rules = [
    ('+10', 'First call within 3 days', 'or +5 later'),
    ('+5', 'Each follow-up you log', null),
    ('+10', 'Guest comes on Sunday or Wednesday', null),
    ('+20', 'Guest joins Workforce or Evangelism', null),
    ('+30', 'Guest becomes a member', null),
  ];
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSizes.gutter, 0, AppSizes.gutter, AppSizes.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How points work', style: AppTextStyles.title),
            SizedBox(height: AppSizes.s4),
            Text('Points start again at the beginning of every month.',
                style: AppTextStyles.bodyMuted),
            SizedBox(height: AppSizes.s16),
            for (final (pts, rule, note) in rules)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.s8),
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.s48,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.sunken,
                        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(pts,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.centered(AppTextStyles.captionStrong)
                              .copyWith(color: AppColors.ink)),
                    ),
                    SizedBox(width: AppSizes.s16),
                    Expanded(child: Text(rule, style: AppTextStyles.body)),
                    if (note != null) Text(note, style: AppTextStyles.caption),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
