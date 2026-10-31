import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/guest_status_pill.dart';
import '../../../core/widgets/metric_tile_widget.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/worker_user.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_state.dart';

/// Profile, personal stats (workers) and sign out. Used by both apps.
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bloc = context.read<AuthBloc>();
    final ok = await AppFeedback.confirm(
      title: 'Sign out?',
      message: 'You can sign back in any time with your Google account.',
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
    final isSigningOut =
        context.select<AuthBloc, bool>((b) => b.state is AuthLoadingState);

    final name = user?.name ?? '';
    final isAdmin = user?.isAdmin ?? false;

    return Column(
      children: [
        const AppHeader(title: 'Me', subtitle: 'Your account and progress'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                AppSizes.gutter, AppSizes.p16, AppSizes.gutter, AppSizes.p24),
            children: [
              AppCard(
                child: Row(
                  children: [
                    AppAvatar(
                      initials: initialsOf(name.isEmpty ? '?' : name),
                      size: AppSizes.avatarLg,
                      background: AppColors.gold,
                      foreground: AppColors.navy,
                    ),
                    SizedBox(width: AppSizes.p12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'Signed in' : name,
                              style: AppTextStyles.cardTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          SizedBox(height: AppSizes.p2),
                          Text(user?.email ?? '',
                              style: AppTextStyles.secondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          SizedBox(height: AppSizes.p8),
                          AppPill(
                            label: user?.role ?? 'Worker',
                            tone: isAdmin ? StatusTone.gold : StatusTone.blue,
                            showDot: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSizes.p16),
              if (!isAdmin) const _MyStats(),
              if (isAdmin) ...[
                const SectionHeader(title: 'Your access'),
                AppCard(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.p16, vertical: AppSizes.p8),
                  child: const Column(
                    children: [
                      InfoRow(
                          icon: Icons.insights_rounded,
                          label: 'Church-wide dashboard',
                          value: 'Yes'),
                      InfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Manage workers',
                          value: 'Yes'),
                      InfoRow(
                          icon: Icons.sync_alt_rounded,
                          label: 'Receives new guests',
                          value: 'No'),
                    ],
                  ),
                ),
              ],
              SizedBox(height: AppSizes.p24),
              AppButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.danger,
                isLoading: isSigningOut,
                onPressed: () => _signOut(context),
              ),
              SizedBox(height: AppSizes.p16),
              Center(
                child: Text('PCU Connect · Pastoral Care Unit',
                    style: AppTextStyles.caption),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Worker stats computed from the guests already loaded for the month.
class _MyStats extends StatelessWidget {
  const _MyStats();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        if (state is! GuestsLoadedState) return const SizedBox.shrink();

        final guests =
            state.allGuests.where((g) => g.month == state.selectedMonth).toList();
        final total = guests.length;
        final contacted = guests.where((g) => g.callCount > 0).length;
        final followUps = guests.fold<int>(0, (sum, g) => sum + g.followUpCount);
        final members = guests.where((g) => g.status == 'Member').length;
        final inTeam = guests.where((g) => g.teamJoined.isNotEmpty).length;
        final returning =
            guests.where((g) => g.sundayAttendance + g.wednesdayAttendance > 0).length;

        double pct(int n) => total == 0 ? 0 : n / total;
        String frac(int n) =>
            '$n of $total · ${(pct(n) * 100).round()}%';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: state.selectedMonth),
            Row(
              children: [
                Expanded(child: MetricTileWidget(value: '$total', label: 'Guests')),
                SizedBox(width: AppSizes.p8),
                Expanded(
                  child: MetricTileWidget(
                    value: '$contacted',
                    label: 'Contacted',
                    valueColor: AppColors.greenInk,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.p8),
            Row(
              children: [
                Expanded(
                    child: MetricTileWidget(value: '$followUps', label: 'Follow-ups')),
                SizedBox(width: AppSizes.p8),
                Expanded(
                  child: MetricTileWidget(
                    value: '$members',
                    label: 'Became members',
                    valueColor: AppColors.goldInk,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.p16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your guests this month', style: AppTextStyles.cardTitle),
                  SizedBox(height: AppSizes.p12),
                  _Funnel(label: 'Contacted', detail: frac(contacted),
                      value: pct(contacted), color: AppColors.green),
                  _Funnel(label: 'Came back to church', detail: frac(returning),
                      value: pct(returning), color: AppColors.blue),
                  _Funnel(label: 'Joined a team', detail: frac(inTeam),
                      value: pct(inTeam), color: AppColors.amber),
                  _Funnel(label: 'Became members', detail: frac(members),
                      value: pct(members), color: AppColors.gold, last: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Funnel extends StatelessWidget {
  final String label;
  final String detail;
  final double value;
  final Color color;
  final bool last;

  const _Funnel({
    required this.label,
    required this.detail,
    required this.value,
    required this.color,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSizes.p12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.secondaryStrong)),
              Text(detail, style: AppTextStyles.caption),
            ],
          ),
          SizedBox(height: AppSizes.p6),
          AppProgressBar(value: value, color: color),
        ],
      ),
    );
  }
}
