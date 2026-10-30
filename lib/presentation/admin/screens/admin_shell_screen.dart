import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/responsive_web_shell.dart';
import 'admin_dashboard_tab.dart';
import 'admin_team_tab.dart';
import 'admin_guests_tab.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentTabIndex = 0;

  final List<Widget> _tabs = const [
    AdminDashboardTab(),
    AdminTeamTab(),
    AdminGuestsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveWebShell(
      maxWidth: 480.0, // Slightly wider for admin data tables
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
            border: Border(top: BorderSide(color: AppColors.line, width: 1)),
          ),
          child: Row(
            children: [
              _buildTabItem(0, Icons.dashboard_rounded, 'Dashboard'),
              _buildTabItem(1, Icons.badge_rounded, 'Team'),
              _buildTabItem(2, Icons.people_alt_rounded, 'Guests'),
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
