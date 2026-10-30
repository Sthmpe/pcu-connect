import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  String _selectedMonth = 'Oct 2026';

  final List<String> _months = [
    'Oct 2026',
    'Sep 2026',
    'Aug 2026',
    'Jul 2026',
    'Jun 2026',
    'May 2026'
  ];

  @override
  Widget build(BuildContext context) {
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
              Text('PCU Leadership', style: AppTextStyles.headerTitle),
              SizedBox(height: 2.h),
              Text(
                '$_selectedMonth · Church-wide guest analytics',
                style: AppTextStyles.headerSubtitle,
              ),
            ],
          ),
        ),

        // Month Selector Chips
        Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: _months.map((m) {
                final isSelected = m == _selectedMonth;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: InkWell(
                    onTap: () => setState(() => _selectedMonth = m),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.navy : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.navy
                              : const Color(0xFFC3CAD6),
                          width: 1.5.w,
                        ),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF3A455A),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Body
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            children: [
              // 4 Headline Metric Tiles
              Row(
                children: [
                  Expanded(
                    child: _buildTile('18', 'New Guests', AppColors.ink),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildTile('5', 'Became Members', AppColors.gold),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildTile('2', 'Not Called', AppColors.red),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildTile('4', 'Joined a Team', AppColors.green),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Retention & Conversion Funnel
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
                    Text(
                      'Church Retention Funnel',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _buildFunnelBar('Contacted', 16, 18),
                    SizedBox(height: 10.h),
                    _buildFunnelBar('Followed up 2+ times', 12, 18),
                    SizedBox(height: 10.h),
                    _buildFunnelBar('Came on Sunday', 9, 18),
                    SizedBox(height: 10.h),
                    _buildFunnelBar('Came on Wednesday', 6, 18),
                    SizedBox(height: 10.h),
                    _buildFunnelBar('Became Members', 5, 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(String count, String label, Color accentColor) {
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
          Text(
            count,
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(label, style: AppTextStyles.tileLabel),
        ],
      ),
    );
  }

  Widget _buildFunnelBar(String label, int current, int total) {
    final pct = total > 0 ? (current / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13.sp, color: AppColors.ink)),
            Text(
              '$current of $total (${(pct * 100).toInt()}%)',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8.h,
            backgroundColor: const Color(0xFFE6EBF4),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.navy),
          ),
        ),
      ],
    );
  }
}
