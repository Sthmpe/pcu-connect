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
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_filter_cubit.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/guest_search_field.dart';
import '../../guests/widgets/watch_months.dart';

/// All church guests for admins. With [workerFilter] it is pushed as its own
/// screen listing one worker's guests. Its month and chip come from the
/// GuestsFilterCubit above it (one per screen), never from the Dashboard.
class AdminGuestsTab extends StatefulWidget {
  final String? workerFilter;

  const AdminGuestsTab({super.key, this.workerFilter});

  @override
  State<AdminGuestsTab> createState() => _AdminGuestsTabState();
}

class _AdminGuestsTabState extends State<AdminGuestsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const _filters = [
    ('all', 'All'),
    ('call', 'Not called'),
    ('mem', 'Members'),
    ('team', 'In a team'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GuestEntity> _visible(GuestsState state, GuestsFilter filter) {
    var list = GuestFilters.apply(state.guestsOf(filter.month), filter.chip);
    final worker = widget.workerFilter?.trim().toLowerCase();
    if (worker != null) {
      list = list
          .where((g) => (g.assignedWorkerName ?? '').trim().toLowerCase() == worker)
          .toList();
    }
    list = GuestFilters.search(list, _query);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final standalone = widget.workerFilter != null;

    return BlocBuilder<GuestsFilterCubit, GuestsFilter>(
      builder: (context, filter) {
        final selection = context.read<GuestsFilterCubit>();
        return WatchMonths(
          months: [filter.month],
          child: BlocBuilder<GuestsBloc, GuestsState>(
            builder: (context, state) {
              final loaded = state.of(filter.month)?.hasData ?? false;
              final monthGuests = state.guestsOf(filter.month);
              final monthPill = MonthPill(month: filter.month, onChanged: selection.selectMonth);

              final controls = !loaded
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
                                count: standalone ? null : GuestFilters.count(monthGuests, key),
                                selected: filter.chip == key || (key == 'all' && filter.chip == 'fu'),
                                onTap: () => selection.selectChip(key),
                              ),
                          ],
                        ),
                      ],
                    );

              final body = _body(context, filter, state, loaded ? _visible(state, filter) : const []);

              if (!standalone) {
                return AppPage(title: 'Guests', trailing: monthPill, below: controls, child: body);
              }
              return Scaffold(
                body: Column(
                  children: [
                    AppTopBar(title: "${firstNameOf(widget.workerFilter!)}'s guests", trailing: monthPill),
                    ?controls,
                    Expanded(child: body),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GuestsFilter filter, GuestsState state, List<GuestEntity> list) {
    final failure = state.failureFor([filter.month]);
    if (failure != null) {
      return ErrorState(
        message: failure,
        onRetry: () => context.read<GuestsBloc>().add(WatchMonthsEvent([filter.month])),
      );
    }
    if (state.waitingFor([filter.month])) return const SkeletonPage();

    return PageList(
      children: [
        if (state.fromCacheIn([filter.month])) OfflineBanner(isRefreshing: state.refreshingIn([filter.month])),
        if (list.isEmpty && _query.isEmpty && filter.chip == 'all' && MonthUtils.isCurrent(filter.month))
          // Early in a month: say so, and offer last month in one tap.
          EmptyState(
            icon: AppIcons.empty,
            message: 'No guests yet in ${MonthUtils.name(filter.month)}.',
            actionLabel: 'See ${MonthUtils.name(MonthUtils.previous(filter.month))}',
            onAction: () => context.read<GuestsFilterCubit>().selectMonth(MonthUtils.previous(filter.month)),
          )
        else if (list.isEmpty)
          EmptyState(
            icon: AppIcons.search,
            message: _query.isNotEmpty
                ? 'No one matches "$_query".'
                : 'No guests here for ${MonthUtils.name(filter.month)}.',
            actionLabel: _query.isNotEmpty ? 'Clear search' : null,
            onAction: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          )
        else
          GroupedCard(
            dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
            children: [
              for (final g in list)
                GuestRow(
                  guest: g,
                  adminView: true,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.guestDetail,
                    arguments: GuestDetailArgs(g.id, asAdmin: true),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
