import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
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
import '../../guests/bloc/guests_state.dart';

/// All church guests for admins. With [workerFilter] it is pushed as its own
/// screen listing one worker's guests.
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

  List<GuestEntity> _visible(GuestsLoadedState state) {
    var list = state.myGuestsFiltered;
    final worker = widget.workerFilter?.trim().toLowerCase();
    if (worker != null) {
      list = list
          .where((g) => (g.assignedWorkerName ?? '').trim().toLowerCase() == worker)
          .toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final digits = q.replaceAll(RegExp(r'\D'), '');
      list = list
          .where((g) =>
              g.name.toLowerCase().contains(q) ||
              (digits.isNotEmpty && g.phone.replaceAll(RegExp(r'\D'), '').contains(digits)))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GuestsBloc>();
    final standalone = widget.workerFilter != null;

    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        final loaded = state is GuestsLoadedState ? state : null;
        final month = loaded?.selectedMonth ?? MonthUtils.current();
        final monthPill = MonthPill(
          month: month,
          onChanged: (m) => bloc.add(SelectMonthEvent(m)),
        );

        final controls = loaded == null
            ? null
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSizes.gutter),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: AppTextStyles.body,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone',
                        prefixIcon: Icon(AppIcons.search,
                            size: AppSizes.iconMd, color: AppColors.muted),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: Icon(AppIcons.close,
                                    size: AppSizes.iconSm, color: AppColors.muted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSizes.s8),
                  ChipBar(
                    chips: [
                      for (final (key, label) in _filters)
                        AppChip(
                          label: label,
                          count: standalone ? null : loaded.countFor(key),
                          selected: loaded.chipFilter == key ||
                              (key == 'all' && loaded.chipFilter == 'fu'),
                          onTap: () => bloc.add(ChangeChipFilterEvent(key)),
                        ),
                    ],
                  ),
                ],
              );

        final body = _body(context, state, loaded == null ? const [] : _visible(loaded));

        if (!standalone) {
          return AppPage(title: 'Guests', trailing: monthPill, below: controls, child: body);
        }
        return Scaffold(
          body: Column(
            children: [
              AppTopBar(
                title: "${firstNameOf(widget.workerFilter!)}'s guests",
                trailing: monthPill,
              ),
              ?controls,
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GuestsState state, List<GuestEntity> list) {
    if (state is GuestsFailureState) {
      return ErrorState(
        message: state.message,
        onRetry: () => context.read<GuestsBloc>().add(const LoadGuestsEvent()),
      );
    }
    if (state is! GuestsLoadedState) return const SkeletonPage();

    return PageList(
      children: [
        if (state.isFromCache) OfflineBanner(isRefreshing: state.isRefreshing),
        if (list.isEmpty)
          EmptyState(
            icon: AppIcons.search,
            message: _query.isNotEmpty
                ? 'No one matches "$_query".'
                : 'No guests here for ${MonthUtils.name(state.selectedMonth)}.',
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
