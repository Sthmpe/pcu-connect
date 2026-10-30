import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/guest_card_widget.dart';
import '../../../core/widgets/metric_tile_widget.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';
import 'guest_detail_screen.dart';

class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuestsBloc, GuestsState>(
      builder: (context, state) {
        if (state is GuestsLoadingState) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navy),
          );
        }

        if (state is! GuestsLoadedState) {
          return const SizedBox.shrink();
        }

        final userName = context.select<AuthBloc, String>((bloc) {
          final s = bloc.state;
          if (s is AuthAuthenticatedState) return s.user.name.split(' ').first;
          return 'Worker';
        });

        final waitingCount = state.todayCallCount;
        final formattedDate = DateFormat('EEE d MMM').format(DateTime.now());

        final filteredList = state.todayFilteredGuests;

        String sectionLabel;
        switch (state.tileFilter) {
          case 'call':
            sectionLabel = 'To call';
            break;
          case 'fu':
            sectionLabel = 'Followed up';
            break;
          case 'mem':
            sectionLabel = 'Members';
            break;
          default:
            sectionLabel = 'All my guests this month';
        }

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
                        Text('Good day, $userName',
                            style: AppTextStyles.headerTitle),
                        SizedBox(height: 2.h),
                        Text(
                          '$formattedDate · $waitingCount guests waiting for a call',
                          style: AppTextStyles.headerSubtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                children: [
                  if (state.isFromCache)
                    Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0D6),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: const Color(0xFFE3B341)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 16.sp, color: const Color(0xFF8A5300)),
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
                    ),

                  // Three Metric Tiles
                  Row(
                    children: [
                      Expanded(
                        child: MetricTileWidget(
                          count: state.todayCallCount,
                          label: 'To call',
                          isSelected: state.tileFilter == 'call',
                          onTap: () {
                            context
                                .read<GuestsBloc>()
                                .add(const ChangeTileFilterEvent('call'));
                          },
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: MetricTileWidget(
                          count: state.todayFollowedUpCount,
                          label: 'Followed up',
                          isSelected: state.tileFilter == 'fu',
                          onTap: () {
                            context
                                .read<GuestsBloc>()
                                .add(const ChangeTileFilterEvent('fu'));
                          },
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: MetricTileWidget(
                          count: state.todayMemberCount,
                          label: 'Members',
                          isSelected: state.tileFilter == 'mem',
                          onTap: () {
                            context
                                .read<GuestsBloc>()
                                .add(const ChangeTileFilterEvent('mem'));
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  // Section Title
                  Padding(
                    padding: EdgeInsets.only(left: 2.w, bottom: 8.h),
                    child: Text(
                      sectionLabel.toUpperCase(),
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),

                  // Guest Cards List
                  if (filteredList.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.h),
                      child: Center(
                        child: Text(
                          'Nothing here yet.',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ),
                    )
                  else
                    ...filteredList.map(
                      (guest) => Padding(
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
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
