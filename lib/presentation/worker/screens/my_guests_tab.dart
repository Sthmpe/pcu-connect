import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/filter_chip_widget.dart';
import '../../../core/widgets/guest_card_widget.dart';
import '../../../core/widgets/month_sheet.dart';
import '../../../core/widgets/state_views.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';

class MyGuestsTab extends StatelessWidget {
  const MyGuestsTab({super.key});

  static const _chips = [
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
        final filtered = loaded?.myGuestsFiltered ?? const <GuestEntity>[];

        return Column(
          children: [
            AppHeader(
              title: 'My guests',
              subtitle: loaded == null
                  ? 'Loading your guests'
                  : '${loaded.selectedMonth} · ${filtered.length} ${filtered.length == 1 ? 'guest' : 'guests'}',
              trailing: loaded == null
                  ? null
                  : HeaderActionButton(
                      icon: Icons.calendar_month_rounded,
                      tooltip: 'Choose month',
                      onTap: () async {
                        final m =
                            await showMonthSheet(context, loaded.selectedMonth);
                        if (m != null) bloc.add(SelectMonthEvent(m));
                      },
                    ),
            ),
            if (loaded != null)
              ChipBar(
                chips: [
                  for (final (key, label) in _chips)
                    FilterChipWidget(
                      label: label,
                      isSelected: loaded.chipFilter == key,
                      onTap: () => bloc.add(ChangeChipFilterEvent(key)),
                    ),
                ],
              ),
            Expanded(child: _list(context, state, filtered)),
          ],
        );
      },
    );
  }

  Widget _list(
      BuildContext context, GuestsState state, List<GuestEntity> filtered) {
    if (state is GuestsFailureState) {
      return ErrorState(
        message: state.message,
        onRetry: () => context.read<GuestsBloc>().add(const LoadGuestsEvent()),
      );
    }
    if (state is! GuestsLoadedState) return const SkeletonList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSizes.gutter, AppSizes.p12, AppSizes.gutter, AppSizes.p24),
      children: [
        if (state.isFromCache) OfflineBanner(isRefreshing: state.isRefreshing),
        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No guests here',
            message: 'Try another filter or month.',
            actionLabel: state.chipFilter == 'all' ? null : 'Show all',
            onAction: () =>
                context.read<GuestsBloc>().add(const ChangeChipFilterEvent('all')),
          )
        else
          for (final guest in filtered)
            Padding(
              padding: EdgeInsets.only(bottom: AppSizes.p8),
              child: GuestCardWidget(
                guest: guest,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.guestDetail,
                  arguments: GuestDetailArgs(guest.id),
                ),
              ),
            ),
        if (filtered.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: AppSizes.p8),
            child: Center(
              child: Text(
                'Tap a guest for details and to log a follow-up',
                style: AppTextStyles.caption,
              ),
            ),
          ),
      ],
    );
  }
}
