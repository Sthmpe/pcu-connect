import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';

class GuestStageBadge extends StatelessWidget {
  final String stage;

  const GuestStageBadge({super.key, required this.stage});

  Color get _color {
    switch (stage) {
      case 'received':
        return AppColors.stageReceived;
      case 'assigned':
        return AppColors.stageAssigned;
      case 'contacted':
        return AppColors.stageContacted;
      case 'returned':
        return AppColors.stageReturned;
      case 'retained':
        return AppColors.stageRetained;
      case 'integrated':
        return AppColors.stageIntegrated;
      case 'operator':
        return AppColors.stageWorker;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.p8,
        vertical: AppSizes.p4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        stage.replaceAll('_', ' '),
        style: AppTextStyles.caption.copyWith(
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
