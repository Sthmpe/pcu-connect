import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class RankingTab extends StatefulWidget {
  const RankingTab({super.key});

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  String _selectedMonth = 'Oct 2026';

  final Map<String, List<Map<String, dynamic>>> _rankings = {
    'Oct 2026': [
      {'name': 'Grace', 'points': 320},
      {'name': 'David', 'points': 280},
      {'name': 'Tolu', 'points': 240},
      {'name': 'Samuel', 'points': 160},
      {'name': 'Ife', 'points': 90},
    ],
    'Sep 2026': [
      {'name': 'David', 'points': 410},
      {'name': 'Grace', 'points': 390},
      {'name': 'Tolu', 'points': 300},
      {'name': 'Ife', 'points': 210},
      {'name': 'Samuel', 'points': 120},
    ],
    'Aug 2026': [
      {'name': 'Grace', 'points': 450},
      {'name': 'Tolu', 'points': 380},
      {'name': 'Samuel', 'points': 330},
      {'name': 'Ife', 'points': 250},
      {'name': 'David', 'points': 210},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final list = _rankings[_selectedMonth] ?? [];
    final first = list.isNotEmpty ? list[0] : null;
    final second = list.length > 1 ? list[1] : null;
    final third = list.length > 2 ? list[2] : null;

    return Column(
      children: [
        // Header
        Container(
          color: AppColors.navy,
          padding: EdgeInsets.fromLTRB(20.w, 42.h, 20.w, 18.h),
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaderboard', style: AppTextStyles.headerTitle),
              SizedBox(height: 2.h),
              Text(
                '$_selectedMonth · Top workers by points',
                style: AppTextStyles.headerSubtitle,
              ),
            ],
          ),
        ),

        // Month selector
        Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: ['Oct 2026', 'Sep 2026', 'Aug 2026'].map((m) {
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
              // Top 3 Podium Cards
              if (first != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 2nd Place
                    if (second != null)
                      Expanded(
                        child: _buildPodiumTile(
                          place: '2nd',
                          name: second['name'],
                          points: second['points'],
                          color: const Color(0xFFC0C0C0),
                          height: 120.h,
                        ),
                      ),
                    SizedBox(width: 8.w),
                    // 1st Place (Tallest)
                    Expanded(
                      child: _buildPodiumTile(
                        place: '1st',
                        name: first['name'],
                        points: first['points'],
                        color: AppColors.gold,
                        height: 150.h,
                        isFirst: true,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // 3rd Place
                    if (third != null)
                      Expanded(
                        child: _buildPodiumTile(
                          place: '3rd',
                          name: third['name'],
                          points: third['points'],
                          color: const Color(0xFFCD7F32),
                          height: 105.h,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16.h),
              ],

              // Your Own Rank Banner
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.gold, size: 28),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Ranking',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFFB9C4D8),
                            ),
                          ),
                          Text(
                            '2nd place · 280 points',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // How points are earned card
              Container(
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
                      'How to earn points',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _buildPointRule('+10 pts', 'First call within 3 days'),
                    _buildPointRule('+5 pts', 'Each follow-up logged'),
                    _buildPointRule('+10 pts', 'Guest attends Sunday or Wednesday'),
                    _buildPointRule('+20 pts', 'Guest joins Workforce / Evangelism'),
                    _buildPointRule('+30 pts', 'Guest becomes a Member'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumTile({
    required String place,
    required String name,
    required int points,
    required Color color,
    required double height,
    bool isFirst = false,
  }) {
    return Container(
      height: height,
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirst ? AppColors.gold : const Color(0xFFE3E6EC),
          width: isFirst ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              place,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            name,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$points pts',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointRule(String pts, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppColors.pillGreenBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              pts,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
