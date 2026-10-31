import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/team_member.dart';
import '../../common/insights_cubits.dart';
import '../../common/load_state.dart';

class WorkerDetailScreen extends StatelessWidget {
  final String workerId;

  const WorkerDetailScreen({super.key, required this.workerId});

  Future<void> _toggle(BuildContext context, TeamMember w, bool active) async {
    final cubit = context.read<TeamCubit>();
    if (!active) {
      final ok = await AppFeedback.confirm(
        title: 'Pause ${w.firstName}?',
        message: 'They stop getting new guests. Their guests and history stay as they are.',
        confirmLabel: 'Pause',
        destructive: true,
      );
      if (!ok) return;
    }
    final result = await cubit.setActive(w.id, active);
    if (result.isFailure) {
      AppFeedback.error('Not changed', result.failure!.message);
    } else {
      AppFeedback.success(
        active ? '${w.firstName} is back in' : '${w.firstName} is paused',
        active ? 'New guests will be shared with them.' : 'No new guests will go to them.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<TeamCubit, LoadState<List<TeamMember>>>(
        builder: (context, state) {
          final w = context.read<TeamCubit>().byId(workerId);
          if (w == null) {
            return const Column(
              children: [
                AppTopBar(),
                Expanded(
                  child: Center(
                    child: EmptyState(icon: AppIcons.search, message: 'We could not find this person.'),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              const AppTopBar(),
              Expanded(
                child: PageList(
                  children: [
                    Column(
                      children: [
                        AppAvatar(name: w.name, size: AppSizes.avatarLg),
                        SizedBox(height: AppSizes.s16),
                        Text(w.name, style: AppTextStyles.title, textAlign: TextAlign.center),
                        SizedBox(height: AppSizes.s4),
                        Text(w.email, style: AppTextStyles.bodyMuted),
                        SizedBox(height: AppSizes.s16),
                        AppPill(label: w.standing, tone: StatusTone.forStanding(w.standing)),
                      ],
                    ),
                    SizedBox(height: AppSizes.s24),
                    if (!w.isAdmin)
                      GroupedCard(
                        children: [
                          AppSwitchRow(
                            title: 'Gets new guests',
                            subtitle: w.active
                                ? 'In the rotation'
                                : 'Paused, not in the rotation',
                            value: w.active,
                            onChanged: (v) => _toggle(context, w, v),
                          ),
                        ],
                      ),
                    if (!w.isAdmin) ...[
                      SectionLabel(MonthUtils.label(state.month)),
                      StatGrid(
                        columns: 3,
                        items: [
                          StatItem('${w.guests}', 'Guests'),
                          StatItem('${w.contacted}', 'Called'),
                          StatItem('${w.followUps}', 'Follow-ups'),
                          StatItem('${w.members}', 'Members'),
                          StatItem('${w.inTeam}', 'In a team'),
                          StatItem('${w.points}', 'Points'),
                        ],
                      ),
                      SizedBox(height: AppSizes.s16),
                      GroupedCard(
                        children: [
                          InfoTile(
                            icon: AppIcons.guests,
                            label: "See ${w.firstName}'s guests",
                            trailing: Icon(AppIcons.chevronRight,
                                size: AppSizes.iconMd, color: AppColors.subtle),
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.workerGuests, arguments: w.name),
                          ),
                        ],
                      ),
                    ] else
                      AppCard(
                        child: Text(
                          'Leaders see the dashboard and manage the team. They never get guests.',
                          style: AppTextStyles.bodyMuted,
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
