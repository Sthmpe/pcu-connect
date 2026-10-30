import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/responsive_web_shell.dart';
import 'today_tab.dart';
import 'my_guests_tab.dart';
import 'ranking_tab.dart';
import 'me_tab.dart';

class WorkerShellScreen extends StatefulWidget {
  const WorkerShellScreen({super.key});

  @override
  State<WorkerShellScreen> createState() => _WorkerShellScreenState();
}

class _WorkerShellScreenState extends State<WorkerShellScreen> {
  int _currentTabIndex = 0;

  final List<Widget> _tabs = const [
    TodayTab(),
    MyGuestsTab(),
    RankingTab(),
    MeTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveWebShell(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(
          index: _currentTabIndex,
          children: _tabs,
        ),
        bottomNavigationBar: Container(
          height: 72.h,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.line, width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildTabItem(0, Icons.home_rounded, 'Today'),
              _buildTabItem(1, Icons.people_alt_rounded, 'Guests'),
              _buildTabItem(2, Icons.emoji_events_rounded, 'Ranking'),
              _buildTabItem(3, Icons.person_rounded, 'Me'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24.r,
              color: isSelected ? AppColors.navy : AppColors.muted,
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.navy : AppColors.muted,
              ),
            ),
            SizedBox(height: 3.h),
            Container(
              width: 20.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
