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
import '../../guests/bloc/guests_state.dart';

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
    final bloc = context.read<GuestsBloc>();

    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        final loaded = state is GuestsLoadedState ? state : null;
        final month = loaded?.selectedMonth ?? MonthUtils.current();

        return AppPage(
          title: 'Guests',
          trailing: MonthPill(
            month: month,
            onChanged: (m) => bloc.add(SelectMonthEvent(m)),
          ),
          below: loaded == null
              ? null
              : ChipBar(
                  chips: [
                    for (final (key, label) in _filters)
                      AppChip(
                        label: label,
                        count: loaded.countFor(key),
                        selected: loaded.chipFilter == key,
                        onTap: () => bloc.add(ChangeChipFilterEvent(key)),
                      ),
                  ],
                ),
          child: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, GuestsState state) {
    final bloc = context.read<GuestsBloc>();
    if (state is GuestsFailureState) {
      return ErrorState(
        message: state.message,
        onRetry: () => bloc.add(const LoadGuestsEvent()),
      );
    }
    if (state is! GuestsLoadedState) return const SkeletonPage();

    final list = state.myGuestsFiltered;
    return PageList(
      children: [
        if (state.isFromCache) OfflineBanner(isRefreshing: state.isRefreshing),
        if (list.isEmpty)
          EmptyState(
            icon: AppIcons.empty,
            message: state.chipFilter == 'all'
                ? 'No guests in ${MonthUtils.name(state.selectedMonth)}.'
                : 'Nobody matches this filter.',
            actionLabel: state.chipFilter == 'all' ? null : 'Show everyone',
            onAction: () => bloc.add(const ChangeChipFilterEvent('all')),
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
