import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../data/firestore/message_templates_repository.dart';
import '../../../domain/entities/worker_user.dart';
import '../../../domain/milestones.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/watch_months.dart';
import 'ranking_tab.dart';

/// Profile, this month at a glance (workers), and sign out. Both apps use it.
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bloc = context.read<AuthBloc>();
    final ok = await AppFeedback.confirm(
      title: 'Sign out?',
      message: 'You can sign back in any time with Google.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (ok) bloc.add(AuthSignOutRequestedEvent());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthBloc, WorkerUser?>((bloc) {
      final s = bloc.state;
      return s is AuthAuthenticatedState ? s.user : null;
    });
    final name = user?.name ?? '';
    final isAdmin = user?.isAdmin ?? false;

    return AppPage(
      title: 'Me',
      child: PageList(
        children: [
          AppCard(
            child: Row(
              children: [
                AppAvatar(
                  name: name.isEmpty ? '?' : name,
                  size: AppSizes.s48 + AppSizes.s8,
                  background: AppColors.navy,
                  foreground: AppColors.gold,
                ),
                SizedBox(width: AppSizes.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: AppSizes.s4 / 2),
                      Text(user?.email ?? '',
                          style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: AppSizes.s8),
                      AppPill(
                        label: user?.role ?? 'Worker',
                        tone: isAdmin ? StatusTone.gold : StatusTone.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isAdmin) const _MonthStats(),
          if (!isAdmin) const MembersHelpedCard(),
          SectionLabel('Account'),
          GroupedCard(
            children: [
              if (!isAdmin)
                InfoTile(
                  icon: AppIcons.star,
                  label: 'How points work',
                  trailing: Icon(AppIcons.chevronRight, size: AppSizes.iconMd, color: AppColors.subtle),
                  onTap: () => showPointsSheet(context),
                ),
              if (isAdmin && context.read<IMessageTemplatesRepository>().canEdit)
                InfoTile(
                  icon: AppIcons.whatsapp,
                  label: 'WhatsApp messages',
                  trailing: Icon(AppIcons.chevronRight, size: AppSizes.iconMd, color: AppColors.subtle),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.messageTemplates),
                ),
              InfoTile(
                icon: AppIcons.signOut,
                label: 'Sign out',
                labelColor: AppColors.redInk,
                onTap: () => _signOut(context),
              ),
            ],
          ),
          SizedBox(height: AppSizes.s24),
          Center(child: Text('PCU Connect, Pastoral Care Unit', style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}

/// "You helped 3 guests become members": this Lagos month, the worker's own
/// guests who became members. Hidden until there is at least one.
class MembersHelpedCard extends StatelessWidget {
  const MembersHelpedCard({super.key});

  /// Members usually first visited a few months before; six months covers them.
  static List<String> months() => MonthUtils.recent(6);

  @override
  Widget build(BuildContext context) {
    final months = MembersHelpedCard.months();
    final thisMonth = months.first;
    return WatchMonths(
      months: months,
      child: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) {
          final n = Milestones.membersHelped(state.guestsIn(months), thisMonth);
          if (n == 0) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(top: AppSizes.s16),
            child: AppCard(
              color: AppColors.goldSoft,
              child: Row(
                children: [
                  Icon(AppIcons.star, size: AppSizes.iconMd, color: AppColors.goldInk),
                  SizedBox(width: AppSizes.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Milestones.helpedLine(n), style: AppTextStyles.bodyStrong),
                        SizedBox(height: AppSizes.s4),
                        Text('In ${MonthUtils.name(thisMonth)}. Thank you for every call.',
                            style: AppTextStyles.caption.copyWith(color: AppColors.goldInk)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthStats extends StatelessWidget {
  const _MonthStats();

  @override
  Widget build(BuildContext context) {
    // This calendar month, whatever month the Guests screen shows.
    final month = MonthUtils.current();
    return WatchMonths(
      months: [month],
      child: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) {
          if (!(state.of(month)?.hasData ?? false)) return const SizedBox.shrink();
          final guests = state.guestsOf(month);
          final followUps = guests.fold<int>(0, (sum, g) => sum + g.followUpCount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(MonthUtils.label(month)),
              StatGrid(items: [
                StatItem('${GuestFilters.count(guests, 'all')}', 'Guests'),
                StatItem('${GuestFilters.count(guests, 'fu')}', 'Called'),
                StatItem('$followUps', 'Follow-ups logged'),
                StatItem('${GuestFilters.count(guests, 'mem')}', 'Became members'),
              ]),
            ],
          );
        },
      ),
    );
  }
}
