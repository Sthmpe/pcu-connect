import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/guest_status_pill.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../cubit/team_cubit.dart';

class AdminTeamTab extends StatelessWidget {
  const AdminTeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamCubit, List<TeamMember>>(
      builder: (context, members) {
        final ranked = context.read<TeamCubit>().ranked;
        final activeCount = members.where((m) => m.active).length;

        return Column(
          children: [
            AppHeader(
              title: 'Team',
              subtitle: '$activeCount active · ranked by new members',
              trailing: HeaderActionButton(
                icon: Icons.add_rounded,
                label: 'Worker',
                tooltip: 'Add a worker',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.addWorker),
              ),
            ),
            Expanded(
              child: ranked.isEmpty
                  ? EmptyState(
                      icon: Icons.group_add_rounded,
                      title: 'No workers yet',
                      message: 'Add the first worker to start the rotation.',
                      actionLabel: 'Add worker',
                      onAction: () =>
                          Navigator.of(context).pushNamed(AppRoutes.addWorker),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(AppSizes.gutter,
                          AppSizes.p16, AppSizes.gutter, AppSizes.p24),
                      itemCount: ranked.length,
                      separatorBuilder: (_, _) => SizedBox(height: AppSizes.p8),
                      itemBuilder: (context, i) => WorkerRow(
                        member: ranked[i],
                        rank: ranked[i].active ? i + 1 : null,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class WorkerRow extends StatelessWidget {
  final TeamMember member;
  final int? rank;

  const WorkerRow({super.key, required this.member, this.rank});

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.forStanding(member.standing);
    final summary = member.active
        ? '${member.guests} guests · ${member.members} ${member.members == 1 ? 'member' : 'members'}'
        : 'Not receiving new guests';

    return Opacity(
      opacity: member.active ? 1 : 0.7,
      child: AppCard(
        padding: EdgeInsets.all(AppSizes.p12),
        onTap: () => Navigator.of(context)
            .pushNamed(AppRoutes.workerDetail, arguments: member.id),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: AppSizes.p20,
                  child: Text(rank == null ? '' : '$rank',
                      style: AppTextStyles.secondaryStrong),
                ),
                AppAvatar(initials: initialsOf(member.name), size: AppSizes.avatarMd),
                SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name,
                          style: AppTextStyles.itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      SizedBox(height: AppSizes.p2),
                      Text(summary,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                SizedBox(width: AppSizes.p8),
                AppPill(label: member.standing, tone: tone),
              ],
            ),
            if (member.active && member.guests > 0) ...[
              SizedBox(height: AppSizes.p10),
              Row(
                children: [
                  SizedBox(width: AppSizes.p20),
                  Expanded(
                    child: AppProgressBar(
                      value: member.contactRate,
                      color: tone.accent,
                    ),
                  ),
                  SizedBox(width: AppSizes.p10),
                  Text('${member.contacted}/${member.guests} called',
                      style: AppTextStyles.caption),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
