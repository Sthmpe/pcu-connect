import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/models/guest_model.dart';
import 'guest_stage_badge.dart';

class GuestListTile extends StatelessWidget {
  final GuestModel guest;
  final VoidCallback onTap;

  const GuestListTile({super.key, required this.guest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p8,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSizes.p16),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.iconLg / 2,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                child: Text(
                  guest.fullName.isNotEmpty
                      ? guest.fullName[0].toUpperCase()
                      : '?',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guest.fullName, style: AppTextStyles.titleMedium),
                    SizedBox(height: AppSizes.p4),
                    Text(guest.phoneOriginal, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              GuestStageBadge(stage: guest.currentStage),
            ],
          ),
        ),
      ),
    );
  }
}
