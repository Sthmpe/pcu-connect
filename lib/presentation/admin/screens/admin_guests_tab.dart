import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
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

/// All church guests for the admin. With [workerFilter] it is pushed as its
/// own screen listing one worker's guests.
class AdminGuestsTab extends StatefulWidget {
  final String? workerFilter;

  const AdminGuestsTab({super.key, this.workerFilter});

  @override
  State<AdminGuestsTab> createState() => _AdminGuestsTabState();
}

class _AdminGuestsTabState extends State<AdminGuestsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _chips = [
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

  List<GuestEntity> _visible(GuestsLoadedState state) {
    var list = state.myGuestsFiltered;
    final worker = widget.workerFilter;
    if (worker != null) {
      final first = worker.split(' ').first.toLowerCase();
      list = list
          .where((g) => (g.assignedWorkerName ?? '').toLowerCase().contains(first))
          .toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((g) =>
              g.name.toLowerCase().contains(q) ||
              g.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GuestsBloc>();
    final standalone = widget.workerFilter != null;

    final content = BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        final loaded = state is GuestsLoadedState ? state : null;
        final list = loaded == null ? const <GuestEntity>[] : _visible(loaded);
        final month = loaded?.selectedMonth ?? kAppMonths.first;

        return Column(
          children: [
            AppHeader(
              title: standalone
                  ? "${widget.workerFilter!.split(' ').first}'s guests"
                  : 'Guests',
              subtitle: '$month · ${list.length} ${list.length == 1 ? 'guest' : 'guests'}',
              onBack: standalone ? () => Navigator.pop(context) : null,
              trailing: loaded == null
                  ? null
                  : HeaderActionButton(
                      icon: Icons.calendar_month_rounded,
                      tooltip: 'Choose month',
                      onTap: () async {
                        final m = await showMonthSheet(context, month);
                        if (m != null) bloc.add(SelectMonthEvent(m));
                      },
                    ),
            ),
            if (loaded != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSizes.gutter, AppSizes.p12, AppSizes.gutter, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: AppTextStyles.input,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name or phone',
                    prefixIcon: Icon(Icons.search_rounded,
                        size: AppSizes.iconMd, color: AppColors.muted),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: Icon(Icons.close_rounded,
                                size: AppSizes.iconSm, color: AppColors.muted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                  ),
                ),
              ),
              ChipBar(
                chips: [
                  for (final (key, label) in _chips)
                    FilterChipWidget(
                      label: label,
                      isSelected: loaded.chipFilter == key ||
                          (key == 'all' && loaded.chipFilter == 'fu'),
                      onTap: () => bloc.add(ChangeChipFilterEvent(key)),
                    ),
                ],
              ),
            ],
            Expanded(child: _list(context, state, list)),
          ],
        );
      },
    );

    return standalone
        ? Scaffold(backgroundColor: AppColors.bg, body: content)
        : content;
  }

  Widget _list(BuildContext context, GuestsState state, List<GuestEntity> list) {
    if (state is GuestsFailureState) {
      return ErrorState(
        message: state.message,
        onRetry: () => context.read<GuestsBloc>().add(const LoadGuestsEvent()),
      );
    }
    if (state is! GuestsLoadedState) return const SkeletonList();

    if (list.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No guests found',
            message: _searchQuery.isNotEmpty
                ? 'Nothing matches "$_searchQuery".'
                : 'Try another filter or month.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          AppSizes.gutter, AppSizes.p12, AppSizes.gutter, AppSizes.p24),
      itemCount: list.length + (state.isFromCache ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: AppSizes.p8),
      itemBuilder: (context, i) {
        if (state.isFromCache && i == 0) {
          return OfflineBanner(isRefreshing: state.isRefreshing);
        }
        final guest = list[i - (state.isFromCache ? 1 : 0)];
        return GuestCardWidget(
          guest: guest,
          showAssignee: true,
          showActions: false,
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.guestDetail,
            arguments: GuestDetailArgs(guest.id, readOnly: true),
          ),
        );
      },
    );
  }
}
