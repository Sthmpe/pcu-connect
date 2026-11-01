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
import '../../common/outstanding_button.dart';
import '../../guests/widgets/guest_search_field.dart';
import '../bloc/today_cubit.dart';
import 'outstanding_screen.dart';
import '../../guests/widgets/watch_months.dart';

/// The worker's Guests screen. Its month and chip live in its own
/// GuestsFilterCubit, so they never change Today or any other screen.
class MyGuestsTab extends StatefulWidget {
  const MyGuestsTab({super.key});

  @override
  State<MyGuestsTab> createState() => _MyGuestsTabState();
}

class _MyGuestsTabState extends State<MyGuestsTab> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _filters = [
    ('all', 'All'),
    ('call', 'To call'),
    ('fu', 'Followed up'),
    ('mem', 'Members'),
    ('team', 'In a team'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Outstanding of every month: a month change never hides waiting work.
                    BlocSelector<TodayCubit, TodayState, int>(
                      selector: (s) => s.loading ? 0 : s.view.outstanding.length,
                      builder: (context, n) => OutstandingButton(count: n, onTap: () => OutstandingScreen.open(context)),
                    ),
                    SizedBox(width: AppSizes.s4),
                    MonthPill(month: filter.month, onChanged: selection.selectMonth, allowAll: true),
                  ],
                ),
                below: month == null || !month.hasData
                    ? null
                    : Column(
                        children: [
                          GuestSearchField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _query = v),
                          ),
                          SizedBox(height: AppSizes.s8),
                          ChipBar(
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

    final outstanding = context.select<TodayCubit, Set<String>>(
        (c) => {for (final i in c.state.view.outstanding) i.guest.id});
    final list = GuestFilters.apply(GuestFilters.search(state.guestsOf(filter.month), _query), filter.chip);
    // All months: the newest visit first.
    if (filter.month == MonthUtils.all) list.sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    final searching = _query.trim().isNotEmpty;
    return PageList(
      children: [
        if (state.fromCacheIn([filter.month])) OfflineBanner(isRefreshing: state.refreshingIn([filter.month])),
        if (list.isEmpty && searching)
          EmptyState(
            icon: AppIcons.search,
            message: 'No one matches "${_query.trim()}".',
            actionLabel: 'Clear search',
            onAction: _clearSearch,
          )
        else if (list.isEmpty)
          EmptyState(
            icon: AppIcons.empty,
            message: filter.chip != 'all'
                ? 'Nobody matches this filter.'
                : filter.month == MonthUtils.all
                    ? 'No guests have been given to you yet.'
                    : 'No guests in ${MonthUtils.name(filter.month)}.',
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
                  outstanding: outstanding.contains(g.id),
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
