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
    return BlocBuilder<RankingCubit, LoadState<Ranking>>(
      builder: (context, state) {
        return AppPage(
          title: 'Ranking',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonthPill(month: state.month, onChanged: cubit.load),
              AppIconButton(
                icon: AppIcons.info,
                tooltip: 'How points work',
                background: Colors.transparent,
                onTap: () => showPointsSheet(context),
              ),
            ],
          ),
          child: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, LoadState<Ranking> state) {
    final data = state.data;
    if (data == null) {
      if (state.status == LoadStatus.failure) {
        return ErrorState(
          message: state.message ?? '',
          onRetry: () => context.read<RankingCubit>().load(),
        );
      }
      return const SkeletonPage(hero: true, rows: 3);
    }

    if (data.entries.isEmpty) {
      return Center(
        child: EmptyState(
          icon: AppIcons.ranking,
          message: 'No points yet in ${MonthUtils.name(state.month)}.',
          actionLabel: 'How points work',
          onAction: () => showPointsSheet(context),
        ),
      );
    }

    final me = data.me;
    final rest = data.entries.skip(3).toList();
    return PageList(
      children: [
        _TopThree(entries: data.entries.take(3).toList(), meEmail: me?.email),
        if (me != null) ...[
          SizedBox(height: AppSizes.s16),
          _MyPosition(me: me, entries: data.entries),
        ],
        if (rest.isNotEmpty) ...[
          SectionLabel('Everyone else'),
          GroupedCard(
            dividerIndent: AppSizes.s16 + AppSizes.s24 + AppSizes.s16 + AppSizes.avatarSm,
            children: [
              for (final e in rest) _RankRow(entry: e, isMe: e.email == me?.email),
            ],
          ),
        ],
      ],
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
                                    '${i + 1}',
                                    style: AppTextStyles.captionStrong.copyWith(
                                      color: i == 0 ? AppColors.navy : AppColors.onNavy,
                                      height: 1,
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

class _MyPosition extends StatelessWidget {
  final RankingEntry me;
  final List<RankingEntry> entries;

  const _MyPosition({required this.me, required this.entries});

  static String _ordinal(int n) {
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

  @override
  Widget build(BuildContext context) {
    final ahead = entries.where((e) => e.points > me.points).toList();
    final String line;
    if (me.rank == 1) {
      line = 'You lead this month. Well done.';
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
                Text('You are ${_ordinal(me.rank)} with ${me.points} points',
                    style: AppTextStyles.bodyStrong.copyWith(color: AppColors.goldInk)),
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

class _RankRow extends StatelessWidget {
  final RankingEntry entry;
  final bool isMe;

  const _RankRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isMe ? AppColors.goldSoft : null,
      constraints: BoxConstraints(minHeight: AppSizes.touch + AppSizes.s8),
      padding: EdgeInsets.symmetric(horizontal: AppSizes.s16),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.s24,
            child: Text('${entry.rank}', style: AppTextStyles.caption),
          ),
          SizedBox(width: AppSizes.s16),
          AppAvatar(name: entry.name, size: AppSizes.avatarSm),
          SizedBox(width: AppSizes.s16),
          Expanded(
            child: Text(isMe ? 'You' : entry.name,
                style: AppTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text('${entry.points} pts', style: AppTextStyles.bodyStrong),
        ],
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
            Text('Points reset at the start of every month.', style: AppTextStyles.bodyMuted),
            SizedBox(height: AppSizes.s16),
            for (final (pts, rule, note) in rules)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.s8),
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.s48,
                      padding: EdgeInsets.symmetric(vertical: AppSizes.s4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.sunken,
                        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(pts, style: AppTextStyles.captionStrong.copyWith(color: AppColors.ink)),
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
