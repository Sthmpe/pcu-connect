import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/filter_chip_widget.dart';
import '../../../core/widgets/guest_card_widget.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';

class AdminGuestsTab extends StatefulWidget {
  const AdminGuestsTab({super.key});

  @override
  State<AdminGuestsTab> createState() => _AdminGuestsTabState();
}

class _AdminGuestsTabState extends State<AdminGuestsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        if (state is! GuestsLoadedState) {
          return const Center(child: CircularProgressIndicator());
        }

        var list = state.allGuests;
        if (_searchQuery.isNotEmpty) {
          list = list
              .where((g) =>
                  g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  g.phone.contains(_searchQuery))
              .toList();
        }

        return Column(
          children: [
            // Dark Header
            Container(
              color: AppColors.navy,
              padding: EdgeInsets.fromLTRB(20.w, 42.h, 20.w, 18.h),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Church Guests', style: AppTextStyles.headerTitle),
                  SizedBox(height: 2.h),
                  Text(
                    '${state.selectedMonth} · Total ${list.length} guests recorded',
                    style: AppTextStyles.headerSubtitle,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by guest name or phone number...',
                  hintStyle: AppTextStyles.bodyMuted,
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.muted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFC3CAD6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFC3CAD6)),
                  ),
                ),
              ),
            ),

            // Chips Row
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    FilterChipWidget(
                      label: 'All',
                      isSelected: state.chipFilter == 'all',
                      onTap: () => context
                          .read<GuestsBloc>()
                          .add(const ChangeChipFilterEvent('all')),
                    ),
                    SizedBox(width: 8.w),
                    FilterChipWidget(
                      label: 'Not called',
                      isSelected: state.chipFilter == 'call',
                      onTap: () => context
                          .read<GuestsBloc>()
                          .add(const ChangeChipFilterEvent('call')),
                    ),
                    SizedBox(width: 8.w),
                    FilterChipWidget(
                      label: 'Members',
                      isSelected: state.chipFilter == 'mem',
                      onTap: () => context
                          .read<GuestsBloc>()
                          .add(const ChangeChipFilterEvent('mem')),
                    ),
                    SizedBox(width: 8.w),
                    FilterChipWidget(
                      label: 'In a team',
                      isSelected: state.chipFilter == 'team',
                      onTap: () => context
                          .read<GuestsBloc>()
                          .add(const ChangeChipFilterEvent('team')),
                    ),
                  ],
                ),
              ),
            ),

            // List
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('No guests found.',
                          style: AppTextStyles.bodyMuted),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 8.h),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final guest = list[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: GuestCardWidget(
                            guest: guest,
                            onTap: () {},
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
