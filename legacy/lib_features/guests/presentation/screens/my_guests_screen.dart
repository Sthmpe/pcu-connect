import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/terminology/terminology_cubit.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/guest_bloc.dart';
import '../bloc/guest_event.dart';
import '../bloc/guest_state.dart';
import '../widgets/guest_list_tile.dart';

class MyGuestsScreen extends StatefulWidget {
  const MyGuestsScreen({super.key});

  @override
  State<MyGuestsScreen> createState() => _MyGuestsScreenState();
}

class _MyGuestsScreenState extends State<MyGuestsScreen> {
  String _stageFilter = 'all';

  static const _filters = [
    'all',
    'assigned',
    'contacted',
    'follow_up_due',
    'retained',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<GuestBloc>().add(
        LoadAssignedGuests(
          operatorId: authState.userProfile.id,
          stageFilter: _stageFilter == 'all' ? null : _stageFilter,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactPlural = context.select(
      (TerminologyCubit c) => c.state.contactPlural,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('My $contactPlural')),
      body: Column(
        children: [
          SizedBox(
            height: 44.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.p16,
                vertical: AppSizes.p8,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => SizedBox(width: AppSizes.p8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = filter == _stageFilter;
                return ChoiceChip(
                  label: Text(filter.replaceAll('_', ' ')),
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                  ),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onSelected: (_) {
                    setState(() => _stageFilter = filter);
                    _load();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<GuestBloc, GuestState>(
              builder: (context, state) {
                if (state is GuestLoading || state is GuestInitial) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (state is GuestFailure) {
                  return Center(
                    child: Text(
                      AppStrings.genericError,
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }
                final guests = (state as GuestLoaded).guests;
                if (guests.isEmpty) {
                  return Center(
                    child: Text(
                      AppStrings.noDataAvailable,
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.p8),
                    itemCount: guests.length,
                    itemBuilder: (context, index) => GuestListTile(
                      guest: guests[index],
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.guestDetail,
                        arguments: guests[index].id,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
