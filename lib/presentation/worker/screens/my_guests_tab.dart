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
import 'guest_detail_screen.dart';

class MyGuestsTab extends StatelessWidget {
  const MyGuestsTab({super.key});

  static const List<String> availableMonths = [
    'Oct 2026',
    'Sep 2026',
    'Aug 2026',
    'Jul 2026',
    'Jun 2026',
    'May 2026'
  ];

  void _showMonthBottomSheet(BuildContext context, String currentMonth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Month',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 12.h),
                ...availableMonths.map((m) {
                  final isSelected = m == currentMonth;
                  return InkWell(
                    onTap: () {
                      context.read<GuestsBloc>().add(SelectMonthEvent(m));
                      Navigator.pop(bottomSheetContext);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.line, width: 1),
                        ),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? AppColors.navy : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        if (state is! GuestsLoadedState) {
          return const SizedBox.shrink();
        }

        final filtered = state.myGuestsFiltered;

        return Column(
          children: [
            // Dark Navy Header matching .hdr
            Container(
              color: AppColors.navy,
              padding: EdgeInsets.fromLTRB(20.w, 42.h, 20.w, 18.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My guests', style: AppTextStyles.headerTitle),
                        SizedBox(height: 2.h),
                        Text(
                          '${state.selectedMonth} · ${filtered.length} guests',
                          style: AppTextStyles.headerSubtitle,
                        ),
                      ],
                    ),
                  ),
                  // Gold Calendar Button matching .calbtn
                  InkWell(
                    onTap: () =>
                        _showMonthBottomSheet(context, state.selectedMonth),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44.r,
                      height: 44.r,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.navy,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips Row
            Container(
              padding: EdgeInsets.symmetric(vertical: 10.h),
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
                      label: 'To call',
                      isSelected: state.chipFilter == 'call',
                      onTap: () => context
                          .read<GuestsBloc>()
                          .add(const ChangeChipFilterEvent('call')),
                    ),
                    SizedBox(width: 8.w),
                    FilterChipWidget(
                      label: 'Followed up',
                      isSelected: state.chipFilter == 'fu',
                      onTap: () => context
                          .read<GuestsBloc>()
                          .add(const ChangeChipFilterEvent('fu')),
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

            // Guests List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No guests match.',
                          style: AppTextStyles.bodyMuted),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 8.h),
                      itemCount: filtered.length + (state.isFromCache ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (state.isFromCache && index == 0) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0D6),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: const Color(0xFFE3B341)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cloud_off_rounded,
                                    size: 16.sp,
                                    color: const Color(0xFF8A5300)),
                                SizedBox(width: 8.w),
                                Text(
                                  'Showing saved data',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8A5300),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final guest =
                            filtered[index - (state.isFromCache ? 1 : 0)];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: GuestCardWidget(
                            guest: guest,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GuestDetailScreen(guestId: guest.id),
                                ),
                              );
                            },
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
