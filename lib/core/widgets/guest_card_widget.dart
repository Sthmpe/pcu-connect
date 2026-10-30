import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/guest_entity.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'guest_status_pill.dart';

class GuestCardWidget extends StatelessWidget {
  final GuestEntity guest;
  final VoidCallback onTap;

  const GuestCardWidget({
    super.key,
    required this.guest,
    required this.onTap,
  });

  Color get _borderColor {
    switch (guest.urgency) {
      case GuestUrgency.green:
        return AppColors.green;
      case GuestUrgency.amber:
        return const Color(0xFFE39A1B);
      case GuestUrgency.red:
        return AppColors.red;
      case GuestUrgency.blue:
        return const Color(0xFF9AA3B2);
    }
  }

  Color get _progressColor {
    switch (guest.urgency) {
      case GuestUrgency.green:
        return AppColors.green;
      case GuestUrgency.amber:
        return const Color(0xFF8A5300);
      case GuestUrgency.red:
        return AppColors.red;
      case GuestUrgency.blue:
        return AppColors.muted;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
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
          border: Border(
            left: BorderSide(color: _borderColor, width: 6.w),
          ),
        ),
        child: Column(
          children: [
            // Top Row: Avatar, Name, Phone, Status Pill
            Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6EBF4),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    guest.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guest.name, style: AppTextStyles.cardTitle),
                      SizedBox(height: 2.h),
                      Text(guest.phone, style: AppTextStyles.bodyMuted),
                    ],
                  ),
                ),
                GuestStatusPill(status: guest.status),
              ],
            ),
            SizedBox(height: 10.h),
            // Bottom Row: Progress Text, WhatsApp Button, Call Button
            Row(
              children: [
                Expanded(
                  child: Text(
                    guest.progressText,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: _progressColor,
                    ),
                  ),
                ),
                // WhatsApp Pill Button
                InkWell(
                  onTap: () => _launchUrl(guest.whatsAppUrl),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: AppColors.btnWhatsAppBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'WhatsApp',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.btnWhatsAppText,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Call Pill Button
                InkWell(
                  onTap: () => _launchUrl(guest.telUrl),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: AppColors.btnCallBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Call',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
