import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/guest_status_pill.dart';
import '../../../core/widgets/metric_tile_widget.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../cubit/team_cubit.dart';

class WorkerDetailScreen extends StatelessWidget {
  final String workerId;

  const WorkerDetailScreen({super.key, required this.workerId});

  Future<void> _remove(BuildContext context, TeamMember w) async {
    final cubit = context.read<TeamCubit>();
    final ok = await AppFeedback.confirm(
      title: 'Remove ${w.firstName}?',
      message:
          'They are made inactive and stop getting guests. Their calls and history are kept.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    cubit.setActive(w.id, false);
    AppFeedback.success('Worker removed', '${w.firstName} no longer gets new guests.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocBuilder<TeamCubit, List<TeamMember>>(
        builder: (context, _) {
          final cubit = context.read<TeamCubit>();
          final w = cubit.byId(workerId);

          if (w == null) {
            return Column(
              children: [
                AppHeader(
                  title: 'Worker',
                  onBack: () => Navigator.pop(context),
                  backLabel: 'Team',
                ),
                const Expanded(
                  child: Center(
                    child: EmptyState(
                      icon: Icons.person_off_rounded,
                      title: 'Worker not found',
                    ),
                  ),
                ),
              ],
            );
          }

          final contactPct = '${(w.contactRate * 100).round()}%';
          final tiles = [
            ('${w.guests}', 'Guests', null),
            ('${w.contacted}', 'Contacted', AppColors.greenInk),
            ('${w.followUps}', 'Follow-ups', null),
            ('${w.members}', 'Members', AppColors.goldInk),
            ('${w.teams}', 'In a team', AppColors.blueInk),
            (contactPct, 'Contact rate', null),
          ];

          return Column(
            children: [
              AppHeader(
                rounded: true,
                onBack: () => Navigator.pop(context),
                backLabel: 'Team',
                child: Row(
                  children: [
                    AppAvatar(
                      initials: initialsOf(w.name),
                      size: AppSizes.avatarLg,
                      background: AppColors.gold,
                      foreground: AppColors.navy,
                    ),
                    SizedBox(width: AppSizes.p12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.name,
                              style: AppTextStyles.detailTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          SizedBox(height: AppSizes.p4),
                          Text(w.email,
                              style: AppTextStyles.screenSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSizes.p8),
                    AppPill(
                        label: w.standing,
                        tone: StatusTone.forStanding(w.standing)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(AppSizes.gutter, AppSizes.p16,
                      AppSizes.gutter, AppSizes.p24),
                  children: [
                    AppCard(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.p16, vertical: AppSizes.p8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Active', style: AppTextStyles.itemTitle),
                                SizedBox(height: AppSizes.p2),
                                Text(
                                  w.active
                                      ? 'Gets new guests in the rotation'
                                      : 'Not getting new guests',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: w.active,
                            onChanged: (v) => cubit.setActive(w.id, v),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSizes.p16),
                    SectionHeader(title: 'This month'),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSizes.p8,
                      crossAxisSpacing: AppSizes.p8,
                      childAspectRatio: 1.25,
                      children: [
                        for (final (value, label, color) in tiles)
                          MetricTileWidget(
                            value: value,
                            label: label,
                            valueColor: color,
                          ),
                      ],
                    ),
                    SizedBox(height: AppSizes.p16),
                    AppCard(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.p16, vertical: AppSizes.p12),
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.workerGuests,
                        arguments: w.name,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_rounded,
                              size: AppSizes.iconMd, color: AppColors.navy),
                          SizedBox(width: AppSizes.p12),
                          Expanded(
                            child: Text("See ${w.firstName}'s guests",
                                style: AppTextStyles.bodyStrong),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: AppSizes.iconMd, color: AppColors.subtle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: w.active ? 'Make inactive' : 'Make active',
                        variant: AppButtonVariant.outline,
                        onPressed: () => cubit.setActive(w.id, !w.active),
                      ),
                    ),
                    SizedBox(width: AppSizes.p10),
                    Expanded(
                      child: AppButton(
                        label: 'Remove',
                        icon: Icons.person_remove_rounded,
                        variant: AppButtonVariant.danger,
                        onPressed: w.active ? () => _remove(context, w) : null,
                      ),
                    ),
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
