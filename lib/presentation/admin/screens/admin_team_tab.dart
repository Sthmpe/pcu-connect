import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AdminTeamTab extends StatefulWidget {
  const AdminTeamTab({super.key});

  @override
  State<AdminTeamTab> createState() => _AdminTeamTabState();
}

class _AdminTeamTabState extends State<AdminTeamTab> {
  final List<Map<String, dynamic>> _workers = [
    {
      'name': 'David Olanite',
      'email': 'davidolanite0@gmail.com',
      'role': 'Worker',
      'standing': 'Outstanding',
      'active': true,
      'guests': 6,
      'contacted': 5,
      'progress': 0.83,
    },
    {
      'name': 'Grace Ade',
      'email': 'grace.ade@example.com',
      'role': 'Worker',
      'standing': 'Outstanding',
      'active': true,
      'guests': 8,
      'contacted': 7,
      'progress': 0.87,
    },
    {
      'name': 'Tolu Bamidele',
      'email': 'tolu@example.com',
      'role': 'Worker',
      'standing': 'On track',
      'active': true,
      'guests': 5,
      'contacted': 4,
      'progress': 0.80,
    },
    {
      'name': 'Samuel Okon',
      'email': 'samuel@example.com',
      'role': 'Worker',
      'standing': 'Behind',
      'active': true,
      'guests': 7,
      'contacted': 3,
      'progress': 0.42,
    },
    {
      'name': 'TEST Worker C',
      'email': 'worker.c@example.com',
      'role': 'Worker',
      'standing': 'Inactive',
      'active': false,
      'guests': 0,
      'contacted': 0,
      'progress': 0.0,
    },
  ];

  void _showAddWorkerDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Worker';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Add New Worker',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Google Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Worker', child: Text('Worker')),
                      DropdownMenuItem(
                          value: 'Admin', child: Text('Admin / HOD')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => role = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.muted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty &&
                        emailCtrl.text.isNotEmpty) {
                      setState(() {
                        _workers.insert(0, {
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'role': role,
                          'standing': 'On track',
                          'active': true,
                          'guests': 0,
                          'contacted': 0,
                          'progress': 0.0,
                        });
                      });
                      Navigator.pop(dialogCtx);
                      Get.snackbar(
                        'Worker Added',
                        '${nameCtrl.text} added to rotation.',
                        backgroundColor: AppColors.green,
                        colorText: Colors.white,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add Worker',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Dark Header
        Container(
          color: AppColors.navy,
          padding: EdgeInsets.fromLTRB(20.w, 42.h, 20.w, 18.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PCU Team', style: AppTextStyles.headerTitle),
                  SizedBox(height: 2.h),
                  Text(
                    '${_workers.where((w) => w['active'] == true).length} active workers',
                    style: AppTextStyles.headerSubtitle,
                  ),
                ],
              ),
              // Add Worker Button
              InkWell(
                onTap: _showAddWorkerDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: AppColors.navy, size: 18),
                      SizedBox(width: 4.w),
                      Text(
                        'Worker',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Workers List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            itemCount: _workers.length,
            itemBuilder: (context, index) {
              final w = _workers[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _buildWorkerCard(w),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> w) {
    Color badgeBg;
    Color badgeText;

    switch (w['standing']) {
      case 'Outstanding':
        badgeBg = AppColors.pillGreenBg;
        badgeText = AppColors.pillGreenText;
        break;
      case 'On track':
        badgeBg = AppColors.pillBlueBg;
        badgeText = AppColors.pillBlueText;
        break;
      case 'Behind':
        badgeBg = AppColors.pillAmberBg;
        badgeText = AppColors.pillAmberText;
        break;
      case 'Inactive':
      default:
        badgeBg = AppColors.pillNeutralBg;
        badgeText = AppColors.pillNeutralText;
        break;
    }

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
        children: [
          Row(
            children: [
              Container(
                width: 42.r,
                height: 42.r,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6EBF4),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  w['name'].toString().substring(0, 2).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.sp,
                    color: AppColors.navy,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w['name'], style: AppTextStyles.cardTitle),
                    SizedBox(height: 2.h),
                    Text(w['email'], style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  w['standing'],
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          if (w['active'] == true) ...[
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${w['contacted']} of ${w['guests']} contacted',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.muted),
                ),
                Text(
                  '${((w['progress'] as double) * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: w['progress'] as double,
                minHeight: 6.h,
                backgroundColor: const Color(0xFFE6EBF4),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.navy),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
