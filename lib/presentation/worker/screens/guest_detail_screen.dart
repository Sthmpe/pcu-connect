import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/guest_status_pill.dart';
import '../../../core/widgets/responsive_web_shell.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_state.dart';
import 'log_follow_up_screen.dart';

class GuestDetailScreen extends StatelessWidget {
  final String guestId;

  const GuestDetailScreen({super.key, required this.guestId});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveWebShell(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: BlocBuilder<GuestsBloc, GuestsState>(
          builder: (context, state) {
            if (state is! GuestsLoadedState) {
              return const Center(child: CircularProgressIndicator());
            }

            final guest = state.allGuests.firstWhere(
              (g) => g.id == guestId,
              orElse: () => state.allGuests.first,
            );

            return Column(
              children: [
                // Rounded Navy Header matching .hdr.round
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32.r),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(16.w, 42.h, 16.w, 22.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFFB9C4D8), size: 14),
                            SizedBox(width: 4.w),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: const Color(0xFFB9C4D8),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Avatar, Name, Phone, Status Pill
                      Row(
                        children: [
                          Container(
                            width: 56.r,
                            height: 56.r,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              guest.initials,
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  guest.name,
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${guest.phone} · came ${guest.month}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: const Color(0xFFB9C4D8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GuestStatusPill(status: guest.status),
                        ],
                      ),
                    ],
                  ),
                ),

                // Body cards
                Expanded(
                  child: ListView(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    children: [
                      // Action Buttons: WhatsApp & Call
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _launchUrl(guest.whatsAppUrl),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50.h,
                                decoration: BoxDecoration(
                                  color: AppColors.btnWhatsAppBg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.btnWhatsAppText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: InkWell(
                              onTap: () => _launchUrl(guest.telUrl),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50.h,
                                decoration: BoxDecoration(
                                  color: AppColors.navy,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Call',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Road to Membership Tracker Card
                      _buildRoadToMembershipCard(guest),
                      SizedBox(height: 12.h),

                      // Last Feedback Card
                      if (guest.lastFeedback.isNotEmpty) ...[
                        _buildCard(
                          title: 'Last Feedback (${guest.lastFeedbackDate})',
                          child: Text(
                            guest.lastFeedback,
                            style: AppTextStyles.body,
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // Team Joined Card
                      if (guest.teamJoined.isNotEmpty) ...[
                        _buildCard(
                          title: 'Team Joined',
                          child: Text(
                            guest.teamJoined,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // Notice
                      Center(
                        child: Text(
                          'Guest details are managed by the HOD',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Footer: Big Gold "Log a follow-up" button matching .foot
                Container(
                  color: Colors.white,
                  padding:
                      EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.line, width: 1),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              LogFollowUpScreen(guestId: guest.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 50.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Log a follow-up',
                        style: AppTextStyles.buttonGold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoadToMembershipCard(GuestEntity guest) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Road to membership (${guest.month})',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),

          // Sundays
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sundays (${guest.sundayAttendance} of 4)',
                  style: AppTextStyles.bodyMuted,
                ),
              ),
              Row(
                children: List.generate(4, (index) {
                  final attended = index < guest.sundayAttendance;
                  return _buildDot(attended, index + 1);
                }),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Wednesdays
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wednesdays (${guest.wednesdayAttendance} of 2)',
                  style: AppTextStyles.bodyMuted,
                ),
              ),
              Row(
                children: List.generate(2, (index) {
                  final attended = index < guest.wednesdayAttendance;
                  return _buildDot(attended, index + 1);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isAttended, int number) {
    return Container(
      width: 30.r,
      height: 30.r,
      margin: EdgeInsets.only(left: 6.w),
      decoration: BoxDecoration(
        color: isAttended ? AppColors.green : const Color(0xFFE6EBF4),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        isAttended ? '✓' : '$number',
        style: TextStyle(
          color: isAttended ? Colors.white : AppColors.muted,
          fontWeight: FontWeight.w600,
          fontSize: 12.sp,
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }
}
