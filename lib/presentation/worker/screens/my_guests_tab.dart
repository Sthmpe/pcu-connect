import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/guest_row.dart';
import '../../../core/widgets/state_views.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_filter_cubit.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/watch_months.dart';

/// The worker's Guests screen. Its month and chip live in its own
/// GuestsFilterCubit, so they never change Today or any other screen.
class MyGuestsTab extends StatelessWidget {
  const MyGuestsTab({super.key});

  static const _filters = [
    ('all', 'All'),
    ('call', 'To call'),
    ('fu', 'Followed up'),
    ('mem', 'Members'),
    ('team', 'In a team'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuestsFilterCubit, GuestsFilter>(
      builder: (context, filter) {
        final selection = context.read<GuestsFilterCubit>();
        return WatchMonths(
          months: [filter.month],
          child: BlocBuilder<GuestsBloc, GuestsState>(
            builder: (context, state) {
              final month = state.of(filter.month);
              final guests = state.guestsOf(filter.month);
              return AppPage(
                title: 'Guests',
                trailing: MonthPill(month: filter.month, onChanged: selection.selectMonth),
                below: month == null || !month.hasData
                    ? null
                    : ChipBar(
                        chips: [
                          for (final (key, label) in _filters)
                            AppChip(
                              label: label,
                              count: GuestFilters.count(guests, key),
                              selected: filter.chip == key,
                              onTap: () => selection.selectChip(key),
                            ),
                        ],
                      ),
                child: _body(context, filter, state),
              );
            },
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GuestsFilter filter, GuestsState state) {
    final failure = state.failureFor([filter.month]);
    if (failure != null) {
      return ErrorState(
        message: failure,
        onRetry: () => context.read<GuestsBloc>().add(WatchMonthsEvent([filter.month])),
      );
    }
    if (state.waitingFor([filter.month])) return const SkeletonPage();

    final list = GuestFilters.apply(state.guestsOf(filter.month), filter.chip);
    return PageList(
      children: [
        if (state.fromCacheIn([filter.month])) OfflineBanner(isRefreshing: state.refreshingIn([filter.month])),
        if (list.isEmpty)
          EmptyState(
            icon: AppIcons.empty,
            message: filter.chip == 'all' ? 'No guests in ${MonthUtils.name(filter.month)}.' : 'Nobody matches this filter.',
            actionLabel: filter.chip == 'all' ? null : 'Show everyone',
            onAction: () => context.read<GuestsFilterCubit>().selectChip('all'),
          )
        else
          GroupedCard(
            dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
            children: [
              for (final g in list)
                GuestRow(
                  guest: g,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.guestDetail,
                    arguments: GuestDetailArgs(g.id),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
