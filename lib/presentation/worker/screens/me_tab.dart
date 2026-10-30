import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String name = 'David Olanite';
        String email = 'davidolanite0@gmail.com';
        String role = 'Worker';

        if (state is AuthAuthenticatedState) {
          name = state.user.name;
          email = state.user.email;
          role = state.user.role;
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
                  Text('My Profile', style: AppTextStyles.headerTitle),
                  SizedBox(height: 2.h),
                  Text('Account & performance stats',
                      style: AppTextStyles.headerSubtitle),
                ],
              ),
            ),

            // Body
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                children: [
                  // Profile Card
                  Container(
                    padding: EdgeInsets.all(16.r),
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
                    child: Row(
                      children: [
                        Container(
                          width: 52.r,
                          height: 52.r,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6EBF4),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 2).toUpperCase() : 'W',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: AppTextStyles.cardTitle),
                              SizedBox(height: 2.h),
                              Text(email, style: AppTextStyles.bodyMuted),
                              SizedBox(height: 4.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.pillBlueBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // Stat Tiles (2x2 Grid)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile('6', 'Total Guests'),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildStatTile('5', 'Contacted'),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile('12', 'Follow-ups'),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildStatTile('2', 'Became Members'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Funnels / Progress Bars
                  Container(
                    padding: EdgeInsets.all(16.r),
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
                        Text('Conversion Funnel',
                            style: TextStyle(
                                fontSize: 15.sp, fontWeight: FontWeight.w600)),
                        SizedBox(height: 12.h),
                        _buildProgressBar(
                            'Called within 3 days', 0.83, '5 of 6 (83%)'),
                        SizedBox(height: 10.h),
                        _buildProgressBar(
                            'Joined a team', 0.33, '2 of 6 (33%)'),
                        SizedBox(height: 10.h),
                        _buildProgressBar(
                            'Became members', 0.33, '2 of 6 (33%)'),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Sign Out Button
                  InkWell(
                    onTap: () {
                      context.read<AuthBloc>().add(AuthSignOutRequestedEvent());
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.red, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.red,
                        ),
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

  Widget _buildStatTile(String count, String label) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count, style: AppTextStyles.tileNumber),
          SizedBox(height: 2.h),
          Text(label, style: AppTextStyles.tileLabel),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String title, double fraction, String trailing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 13.sp, color: AppColors.ink)),
            Text(trailing,
                style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8.h,
            backgroundColor: const Color(0xFFE6EBF4),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
          ),
        ),
      ],
    );
  }
}
