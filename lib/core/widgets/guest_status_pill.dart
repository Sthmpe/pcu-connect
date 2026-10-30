import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class GuestStatusPill extends StatelessWidget {
  final String status;

  const GuestStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (status) {
      case 'Returning':
        bg = AppColors.pillGreenBg;
        text = AppColors.pillGreenText;
        break;
      case 'Contacted':
        bg = AppColors.pillAmberBg;
        text = AppColors.pillAmberText;
        break;
      case 'Unreachable':
        bg = AppColors.pillRedBg;
        text = AppColors.pillRedText;
        break;
      case 'New guest':
        bg = AppColors.pillBlueBg;
        text = AppColors.pillBlueText;
        break;
      case 'Member':
        bg = AppColors.pillGoldBg;
        text = AppColors.pillGoldText;
        break;
      case 'Not interested':
      default:
        bg = AppColors.pillNeutralBg;
        text = AppColors.pillNeutralText;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: AppTextStyles.pill.copyWith(color: text),
      ),
    );
  }
}
