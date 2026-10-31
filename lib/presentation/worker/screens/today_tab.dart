import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/guest_row.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';

class TodayTab extends StatelessWidget {
  final VoidCallback? onSeeAll;

  const TodayTab({super.key, this.onSeeAll});

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _filters = [
    ('all', 'All'),
    ('call', 'To call'),
    ('fu', 'Followed up'),
    ('mem', 'Members'),
  ];

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
      child: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) {
          final bloc = context.read<GuestsBloc>();
          if (state is GuestsFailureState) {
            return ErrorState(
              message: state.message,
              onRetry: () => bloc.add(const LoadGuestsEvent()),
            );
          }
          if (state is! GuestsLoadedState) return const SkeletonPage(hero: true);

          final list = state.todayFilteredGuests;
          return RefreshIndicator(
            color: AppColors.navy,
            onRefresh: () async {
              bloc.add(const LoadGuestsEvent());
              await bloc.stream
                  .firstWhere((s) => s is! GuestsLoadedState || !s.isRefreshing)
                  .timeout(const Duration(seconds: 25), onTimeout: () => state);
            },
            child: ListView(
              padding: EdgeInsets.only(top: AppSizes.s8, bottom: AppSizes.s32),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.gutter),
                  child: Column(
                    children: [
                      if (state.isFromCache) OfflineBanner(isRefreshing: state.isRefreshing),
                      _ProgressHero(state: state),
                    ],
                  ),
                ),
                SizedBox(height: AppSizes.s16),
                ChipBar(
                  chips: [
                    for (final (key, label) in _filters)
                      AppChip(
                        label: label,
                        count: state.countFor(key),
                        selected: state.tileFilter == key,
                        onTap: () => bloc.add(ChangeTileFilterEvent(key)),
                      ),
                  ],
                ),
                SizedBox(height: AppSizes.s8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.gutter),
                  child: AnimatedSwitcher(
                    duration: AppDurations.normal,
                    child: list.isEmpty
                        ? _emptyFor(state.tileFilter, bloc)
                        : GroupedCard(
                            key: ValueKey(state.tileFilter),
                            dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
                            children: [
                              for (final g in list)
                                GuestRow(guest: g, onTap: () => _open(context, g)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _open(BuildContext context, GuestEntity g) {
    Navigator.of(context)
        .pushNamed(AppRoutes.guestDetail, arguments: GuestDetailArgs(g.id));
  }

  Widget _emptyFor(String filter, GuestsBloc bloc) {
    switch (filter) {
      case 'call':
        return EmptyState(
          key: const ValueKey('empty-call'),
          icon: AppIcons.done,
          message: 'No one is waiting for a call.',
          actionLabel: 'Show everyone',
          onAction: () => bloc.add(const ChangeTileFilterEvent('all')),
        );
      case 'all':
        return const EmptyState(
          key: ValueKey('empty-all'),
          icon: AppIcons.empty,
          message: 'No guests assigned to you this month yet.',
        );
      default:
        return EmptyState(
          key: ValueKey('empty-$filter'),
          icon: AppIcons.empty,
          message: 'Nobody here yet.',
          actionLabel: 'Show everyone',
          onAction: () => bloc.add(const ChangeTileFilterEvent('all')),
        );
    }
  }
}

/// Navy summary card: progress ring, one line of context, the next call.
class _ProgressHero extends StatelessWidget {
  final GuestsLoadedState state;

  const _ProgressHero({required this.state});

  @override
  Widget build(BuildContext context) {
    final total = state.countFor('all');
    final called = state.countFor('fu');
    final waiting = total - called;
    final pct = total == 0 ? 0.0 : called / total;
    final next = state.nextToCall;

    final String headline;
    final String detail;
    if (total == 0) {
      headline = 'No guests yet';
      detail = 'New guests will show up here.';
    } else if (waiting == 0) {
      headline = 'Everyone has a call';
      detail = 'All $total guests this month. Lovely work.';
    } else {
      headline = '$called of $total guests called';
      detail = '$waiting still ${waiting == 1 ? 'waits' : 'wait'} for a call';
    }

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
              ProgressRing(
                value: pct,
                size: 72,
                stroke: 6,
                color: AppColors.onNavy,
                trackColor: AppColors.onNavy.withValues(alpha: 0.14),
                child: Text(
                  '${(pct * 100).round()}%',
                  style: AppTextStyles.bodyStrong.copyWith(color: AppColors.onNavy),
                ),
              ),
              SizedBox(width: AppSizes.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        style: AppTextStyles.title.copyWith(color: AppColors.onNavy)),
                    SizedBox(height: AppSizes.s4),
                    Text(detail,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.onNavyMuted)),
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
                Navigator.of(context).pushNamed(AppRoutes.guestDetail,
                    arguments: GuestDetailArgs(next.id));
                ContactLauncher.call(next);
              },
            ),
          ],
        ],
      ),
    );
  }
}
