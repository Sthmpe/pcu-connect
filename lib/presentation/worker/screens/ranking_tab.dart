import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/filter_chip_widget.dart';
import '../../../core/widgets/month_sheet.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class RankingTab extends StatefulWidget {
  const RankingTab({super.key});

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  String _selectedMonth = 'Oct 2026';

  // Sample standings until the Apps Script `ranking` action is wired in.
  static const Map<String, List<(String, int)>> _rankings = {
    'Oct 2026': [
      ('Grace', 320),
      ('David', 280),
      ('Tolu', 240),
      ('Samuel', 160),
      ('Ife', 90),
    ],
    'Sep 2026': [
      ('David', 410),
      ('Grace', 390),
      ('Tolu', 300),
      ('Ife', 210),
      ('Samuel', 120),
    ],
    'Aug 2026': [
      ('Grace', 450),
      ('Tolu', 380),
      ('Samuel', 330),
      ('Ife', 250),
      ('David', 210),
    ],
  };

  static const _pointRules = [
    ('+10', 'First call within 3 days', '+5 after'),
    ('+5', 'Each follow-up logged', null),
    ('+10', 'Guest attends Sunday or Wednesday', null),
    ('+20', 'Guest joins Workforce or Evangelism', null),
    ('+30', 'Guest becomes a Member', null),
  ];

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AuthBloc, String>((bloc) {
      final s = bloc.state;
      return s is AuthAuthenticatedState ? s.user.name.split(' ').first : '';
    });
    final list = _rankings[_selectedMonth] ?? const [];
    final myIndex = list.indexWhere((e) => e.$1 == firstName);

    return Column(
      children: [
        AppHeader(
          title: 'Ranking',
          subtitle: '$_selectedMonth · Points earned by workers',
        ),
        ChipBar(
          chips: [
            for (final m in _rankings.keys)
              FilterChipWidget(
                label: shortMonth(m),
                isSelected: m == _selectedMonth,
                onTap: () => setState(() => _selectedMonth = m),
              ),
          ],
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No points yet',
                  message: 'Rankings appear once follow-ups are logged.',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(AppSizes.gutter, AppSizes.p16,
                      AppSizes.gutter, AppSizes.p24),
                  children: [
                    _Podium(entries: list.take(3).toList(), me: firstName),
                    SizedBox(height: AppSizes.p16),
                    _MyRankCard(
                      rank: myIndex < 0 ? null : myIndex + 1,
                      points: myIndex < 0 ? 0 : list[myIndex].$2,
                      gapToNext: myIndex > 0
                          ? list[myIndex - 1].$2 - list[myIndex].$2
                          : null,
                    ),
                    if (list.length > 3) ...[
                      SizedBox(height: AppSizes.p16),
                      const SectionHeader(title: 'Everyone else'),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 3; i < list.length; i++) ...[
                              if (i > 3) const Divider(),
                              _RankRow(
                                rank: i + 1,
                                name: list[i].$1,
                                points: list[i].$2,
                                isMe: list[i].$1 == firstName,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: AppSizes.p16),
                    const SectionHeader(title: 'How to earn points'),
                    AppCard(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.p16, vertical: AppSizes.p8),
                      child: Column(
                        children: [
                          for (final (pts, rule, note) in _pointRules)
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: AppSizes.p6),
                              child: Row(
                                children: [
                                  Container(
                                    width: AppSizes.p40,
                                    padding: EdgeInsets.symmetric(
                                        vertical: AppSizes.p4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.goldSoft,
                                      borderRadius: BorderRadius.circular(
                                          AppSizes.radiusSm),
                                    ),
                                    child: Text(
                                      pts,
                                      style: AppTextStyles.captionStrong
                                          .copyWith(color: AppColors.goldInk),
                                    ),
                                  ),
                                  SizedBox(width: AppSizes.p12),
                                  Expanded(
                                      child: Text(rule,
                                          style: AppTextStyles.secondaryStrong)),
                                  if (note != null)
                                    Text(note, style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  final List<(String, int)> entries;
  final String me;

  const _Podium({required this.entries, required this.me});

  @override
  Widget build(BuildContext context) {
    // Display order: 2nd, 1st, 3rd
    final order = [1, 0, 2];
    const medals = [AppColors.gold, AppColors.silver, AppColors.bronze];
    final heights = [AppSizes.p40 + AppSizes.p32, AppSizes.p40 + AppSizes.p12, AppSizes.p40];

    return AppCard(
      padding: EdgeInsets.fromLTRB(
          AppSizes.p12, AppSizes.p20, AppSizes.p12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final i in order)
            Expanded(
              child: i >= entries.length
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            AppAvatar(
                              initials: initialsOf(entries[i].$1),
                              size: i == 0 ? AppSizes.avatarLg : AppSizes.avatarMd + 4,
                              background: i == 0 ? AppColors.goldSoft : AppColors.navySoft,
                              foreground: i == 0 ? AppColors.goldInk : AppColors.navy,
                              ring: medals[i],
                            ),
                            if (i == 0)
                              Positioned(
                                top: -AppSizes.p16,
                                child: Icon(Icons.workspace_premium_rounded,
                                    color: AppColors.gold, size: AppSizes.iconLg),
                              ),
                          ],
                        ),
                        SizedBox(height: AppSizes.p6),
                        Text(
                          entries[i].$1 == me ? 'You' : entries[i].$1,
                          style: AppTextStyles.itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('${entries[i].$2} pts', style: AppTextStyles.caption),
                        SizedBox(height: AppSizes.p8),
                        Container(
                          height: heights[i],
                          margin: EdgeInsets.symmetric(horizontal: AppSizes.p4),
                          alignment: Alignment.topCenter,
                          padding: EdgeInsets.only(top: AppSizes.p8),
                          decoration: BoxDecoration(
                            color: i == 0 ? AppColors.navy : AppColors.navySoft,
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(AppSizes.radiusMd)),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: AppTextStyles.numberSm.copyWith(
                              color: i == 0 ? AppColors.gold : AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final int? rank;
  final int points;
  final int? gapToNext;

  const _MyRankCard({required this.rank, required this.points, this.gapToNext});

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
    final String headline;
    final String detail;
    if (rank == null) {
      headline = 'Not ranked yet';
      detail = 'Log a follow-up to get on the board.';
    } else if (rank == 1) {
      headline = '1st place · $points pts';
      detail = 'You are leading this month. Well done!';
    } else {
      headline = '${_ordinal(rank!)} place · $points pts';
      detail = gapToNext == null
          ? 'Keep going.'
          : '$gapToNext pts to move up a place.';
    }

    return Container(
      padding: EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded,
                color: AppColors.gold, size: AppSizes.iconMd),
          ),
          SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR RANK',
                    style: AppTextStyles.overline
                        .copyWith(color: AppColors.onNavyMuted)),
                SizedBox(height: AppSizes.p2),
                Text(headline,
                    style: AppTextStyles.cardTitle
                        .copyWith(color: AppColors.onNavy)),
                SizedBox(height: AppSizes.p2),
                Text(detail,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.onNavyMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final int points;
  final bool isMe;

  const _RankRow({
    required this.rank,
    required this.name,
    required this.points,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isMe ? AppColors.goldSoft : null,
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.p16, vertical: AppSizes.p10),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.p24,
            child: Text('$rank', style: AppTextStyles.secondaryStrong),
          ),
          AppAvatar(initials: initialsOf(name), size: AppSizes.avatarSm),
          SizedBox(width: AppSizes.p12),
          Expanded(
            child: Text(isMe ? '$name (you)' : name,
                style: AppTextStyles.bodyStrong),
          ),
          Text('$points pts', style: AppTextStyles.secondaryStrong),
        ],
      ),
    );
  }
}
