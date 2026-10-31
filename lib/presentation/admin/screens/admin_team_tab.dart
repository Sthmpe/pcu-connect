import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/team_member.dart';
import '../../common/insights_cubits.dart';
import '../../common/load_state.dart';

class AdminTeamTab extends StatelessWidget {
  const AdminTeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamCubit, LoadState<List<TeamMember>>>(
      builder: (context, state) {
        final cubit = context.read<TeamCubit>();
        final members = cubit.ranked;
        final workers = members.where((m) => m.active && !m.isAdmin).toList();
        final admins = members.where((m) => m.active && m.isAdmin).toList();
        final inactive = members.where((m) => !m.active).toList();

        return AppPage(
          title: 'Team',
          subtitle: state.data == null
              ? null
              : '${workers.length} active ${workers.length == 1 ? 'worker' : 'workers'}',
          trailing: AppIconButton(
            icon: AppIcons.add,
            tooltip: 'Add a worker',
            background: AppColors.gold,
            foreground: AppColors.navy,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.addWorker),
          ),
          child: state.data == null
              ? (state.status == LoadStatus.failure
                  ? ErrorState(message: state.message ?? '', onRetry: cubit.load)
                  : const SkeletonPage())
              : members.isEmpty
                  ? Center(
                      child: EmptyState(
                        icon: AppIcons.addPerson,
                        message: 'Add your first worker to start sharing guests.',
                        actionLabel: 'Add worker',
                        onAction: () => Navigator.of(context).pushNamed(AppRoutes.addWorker),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.navy,
                      onRefresh: cubit.load,
                      child: PageList(
                        children: [
                          if (workers.isNotEmpty) _section(null, workers),
                          if (admins.isNotEmpty) _section('Leaders', admins),
                          if (inactive.isNotEmpty) _section('Inactive', inactive),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _section(String? title, List<TeamMember> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) SectionLabel(title),
        GroupedCard(
          dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
          children: [for (final m in list) WorkerRow(member: m)],
        ),
      ],
    );
  }
}

class WorkerRow extends StatelessWidget {
  final TeamMember member;

  const WorkerRow({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final summary = !member.active
        ? 'Not getting new guests'
        : member.isAdmin
            ? member.email
            : '${member.guests} guests · ${member.members} ${member.members == 1 ? 'member' : 'members'}';

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.workerDetail, arguments: member.id),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s8 + 4),
        child: Row(
          children: [
            AppAvatar(name: member.name, size: AppSizes.avatarMd),
            SizedBox(width: AppSizes.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name,
                      style: AppTextStyles.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: AppSizes.s4),
                  Text(summary,
                      style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (member.active && !member.isAdmin) ...[
              SizedBox(width: AppSizes.s8),
              AppPill(label: member.standing, tone: StatusTone.forStanding(member.standing)),
            ] else
              Icon(AppIcons.chevronRight, size: AppSizes.iconMd, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}
