import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/guest_row.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../../domain/today_rules.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../common/notification_bell.dart';
import '../../common/push_prompt_card.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/watch_months.dart';

/// Today: the worker's guests who need a call now (TodayRules). It does not
/// follow any month filter; the Guests screen's month never changes it.
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
    final months = TodayRules.months(since: AppConfig.chaseFrom);

    return WatchMonths(
      months: months,
      child: AppPage(
        eyebrow: DateFormat('EEEE, d MMMM').format(now),
        title: firstName.isEmpty ? _greeting(now) : '${_greeting(now)}, $firstName',
        trailing: const NotificationBell(),
        child: BlocBuilder<GuestsBloc, GuestsState>(
          builder: (context, state) {
            final bloc = context.read<GuestsBloc>();
            final failure = state.failureFor(months);
            if (failure != null) {
              return ErrorState(message: failure, onRetry: () => bloc.add(WatchMonthsEvent(months)));
            }
            if (state.waitingFor(months)) return const SkeletonPage(hero: true);

            final view = TodayRules.of(state.guestsIn(months), since: AppConfig.chaseFrom);
            return RefreshIndicator(
              color: AppColors.navy,
              onRefresh: () async {
                // Live lists (Firestore) are already current: just acknowledge.
                if (AppConfig.useFirestore) {
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  return;
                }
                bloc.add(RefreshMonthsEvent(months));
                await bloc.stream
                    .firstWhere((s) => !s.refreshingIn(months))
                    .timeout(const Duration(seconds: 25), onTimeout: () => state);
              },
              child: ListView(
                padding: EdgeInsets.only(top: AppSizes.s8, bottom: AppSizes.s32),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSizes.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.fromCacheIn(months))
                          OfflineBanner(isRefreshing: state.refreshingIn(months)),
                        const PushPromptCard(reason: 'when a new guest is assigned to you'),
                        _TodayHero(view: view),
                        if (view.total == 0) ...[
                          SizedBox(height: AppSizes.s24),
                          EmptyState(
                            icon: AppIcons.done,
                            message: 'No one is waiting for a first call. Lovely work.',
                            actionLabel: onSeeAll == null ? null : 'See all your guests',
                            onAction: onSeeAll,
                          ),
                        ],
                        if (view.outstanding.isNotEmpty) ...[
                          SectionLabel('Outstanding · ${view.outstanding.length}'),
                          Padding(
                            padding: EdgeInsets.only(bottom: AppSizes.s8),
                            child: Text('More than 3 days since their visit, still no first call.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.redInk)),
                          ),
                          _list(context, view.outstanding),
                        ],
                        if (view.fresh.isNotEmpty) ...[
                          SectionLabel('New · ${view.fresh.length}'),
                          Padding(
                            padding: EdgeInsets.only(bottom: AppSizes.s8),
                            child: Text('Call within 3 days of their visit.', style: AppTextStyles.caption),
                          ),
                          _list(context, view.fresh),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _list(BuildContext context, List<GuestEntity> guests) => GroupedCard(
        dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
        children: [for (final g in guests) GuestRow(guest: g, onTap: () => _open(context, g))],
      );

  static void _open(BuildContext context, GuestEntity g) {
    Navigator.of(context).pushNamed(AppRoutes.guestDetail, arguments: GuestDetailArgs(g.id));
  }
}

/// Navy summary card: how many need a call, how many are outstanding, the next call.
class _TodayHero extends StatelessWidget {
  final TodayView view;

  const _TodayHero({required this.view});

  @override
  Widget build(BuildContext context) {
    final total = view.total;
    final outstanding = view.outstanding.length;
    final next = view.next;
    final headline = total == 0
        ? 'All caught up'
        : '$total ${total == 1 ? 'guest needs' : 'guests need'} a first call';
    final detail = total == 0
        ? 'New guests will show up here.'
        : outstanding == 0
            ? 'All within their 3 days.'
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
                decoration: BoxDecoration(
                  color: AppColors.onNavy.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
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
              label: 'Call ${firstNameOf(next.name)} next',
              icon: AppIcons.call,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.guestDetail, arguments: GuestDetailArgs(next.id));
                ContactLauncher.call(next);
              },
            ),
          ],
        ],
      ),
    );
  }
}
