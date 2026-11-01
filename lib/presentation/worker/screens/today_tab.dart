import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/work_rules.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/guest_row.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/today_rules.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../common/notification_bell.dart';
import '../../common/push_prompt_card.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../bloc/today_cubit.dart';

/// Today: the worker's to-do list (TodayRules): New, Outstanding, Retry and
/// Follow-up due. It follows no month filter.
class TodayTab extends StatelessWidget {
  final VoidCallback? onSeeAll;

  const TodayTab({super.key, this.onSeeAll});

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AuthBloc, String>((bloc) {
      final s = bloc.state;
      return s is AuthAuthenticatedState ? firstNameOf(s.user.name) : '';
    });
    final now = DateTime.now();

    return AppPage(
      eyebrow: DateFormat('EEEE, d MMMM').format(now),
      title: firstName.isEmpty ? _greeting(now) : '${_greeting(now)}, $firstName',
      trailing: const NotificationBell(),
      child: BlocBuilder<TodayCubit, TodayState>(
        builder: (context, state) {
          final guests = context.read<GuestsBloc>();
          if (state.failure != null) {
            return ErrorState(message: state.failure!, onRetry: () => guests.add(WatchMonthsEvent(state.months)));
          }
          if (state.loading) return const SkeletonPage(hero: true);

          final view = state.view;
          return RefreshIndicator(
            color: AppColors.navy,
            onRefresh: () async {
              // Live lists (Firestore) are already current: just acknowledge.
              if (AppConfig.useFirestore) {
                await Future<void>.delayed(const Duration(milliseconds: 400));
                return;
              }
              guests.add(RefreshMonthsEvent(state.months));
              await guests.stream
                  .firstWhere((s) => !s.refreshingIn(state.months))
                  .timeout(const Duration(seconds: 25), onTimeout: () => guests.state);
            },
            child: ListView(
              padding: EdgeInsets.only(top: AppSizes.s8, bottom: AppSizes.s32),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.fromCache) OfflineBanner(isRefreshing: state.refreshing),
                      const PushPromptCard(reason: 'when a new guest is assigned to you'),
                      TodayHero(view: view),
                      if (view.total == 0) ...[
                        SizedBox(height: AppSizes.s24),
                        EmptyState(
                          icon: AppIcons.done,
                          message: 'Nothing waiting for you today. Lovely work.',
                          actionLabel: onSeeAll == null ? null : 'See all your guests',
                          onAction: onSeeAll,
                        ),
                      ],
                      _section(context, 'New', 'Call within 3 days of their visit.', view.fresh),
                      _section(context, 'Outstanding', 'More than 3 days since their visit, still no first call.',
                          view.outstanding,
                          captionColor: AppColors.redInk),
                      _section(context, 'Retry', 'No answer last time. Try again today.', view.retry),
                      _section(context, 'Follow-up due', 'No call for ${WorkRules.FOLLOWUP_DUE_AFTER_DAYS} days or more.',
                          view.followUpDue),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _section(BuildContext context, String title, String caption, List<TodayItem> items,
      {Color? captionColor}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('$title · ${items.length}'),
        Padding(
          padding: EdgeInsets.only(bottom: AppSizes.s8),
          child: Text(caption,
              style: captionColor == null ? AppTextStyles.caption : AppTextStyles.caption.copyWith(color: captionColor)),
        ),
        GroupedCard(
          dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
          children: [
            for (final i in items)
              GuestRow(
                guest: i.guest,
                line: todayLine(i),
                pill: todayPill(i.section),
                pillTone: i.section == TodaySection.outstanding ? StatusTone.red : StatusTone.neutral,
                onTap: () => _open(context, i),
              ),
          ],
        ),
      ],
    );
  }

  static void _open(BuildContext context, TodayItem i) {
    Navigator.of(context).pushNamed(AppRoutes.guestDetail, arguments: GuestDetailArgs(i.guest.id));
  }
}

String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

/// The line under a guest's name on Today.
String todayLine(TodayItem i) => switch (i.section) {
      TodaySection.fresh => i.days <= 0 ? 'Visited today, call soon' : 'Visited ${_days(i.days)} ago',
      TodaySection.outstanding => 'Waiting ${_days(i.days)} for a call',
      TodaySection.retry => 'No answer ${_days(i.days)} ago, call ${i.calls + 1} of ${WorkRules.MAX_RETRIES}',
      TodaySection.followUpDue => 'Last call ${_days(i.days)} ago',
    };

/// The pill on a Today row: red for Outstanding, quiet for Retry and Follow-up due.
String? todayPill(TodaySection s) => switch (s) {
      TodaySection.fresh => null,
      TodaySection.outstanding => 'Outstanding',
      TodaySection.retry => 'Retry',
      TodaySection.followUpDue => 'Follow-up due',
    };

/// Navy summary card: how many need action today, and the next call.
class TodayHero extends StatelessWidget {
  final TodayView view;

  const TodayHero({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final total = view.total;
    final outstanding = view.outstanding.length;
    final next = view.next;
    final headline = total == 0 ? 'All caught up' : '$total ${total == 1 ? 'guest needs' : 'guests need'} a call';
    final detail = total == 0
        ? 'New guests will show up here.'
        : outstanding == 0
            ? 'None is outstanding.'
            : '$outstanding ${outstanding == 1 ? 'is' : 'are'} outstanding.';

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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.onNavy.withValues(alpha: 0.10), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$total', style: AppTextStyles.display.copyWith(color: AppColors.onNavy)),
              ),
              SizedBox(width: AppSizes.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: AppTextStyles.title.copyWith(color: AppColors.onNavy)),
                    SizedBox(height: AppSizes.s4),
                    Text(detail, style: AppTextStyles.caption.copyWith(color: AppColors.onNavyMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (next != null) ...[
            SizedBox(height: AppSizes.s24),
            AppButton(
              label: 'Call ${firstNameOf(next.guest.name)} next',
              icon: AppIcons.call,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.guestDetail, arguments: GuestDetailArgs(next.guest.id));
                ContactLauncher.call(next.guest);
              },
            ),
          ],
        ],
      ),
    );
  }
}
