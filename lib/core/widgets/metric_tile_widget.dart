import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// Number tile. Tappable tiles act as filters and show a gold outline when
/// selected.
class MetricTileWidget extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const MetricTileWidget({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.icon,
    this.iconColor,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusLg);
    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.goldSoft : AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.line,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                AppSizes.p12, AppSizes.p12, AppSizes.p8, AppSizes.p12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: AppTextStyles.number
                            .copyWith(color: valueColor ?? AppColors.ink),
                      ),
                    ),
                    if (icon != null)
                      Icon(icon,
                          size: AppSizes.iconSm,
                          color: iconColor ?? AppColors.subtle),
                  ],
                ),
                SizedBox(height: AppSizes.p4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null)
                      Icon(Icons.chevron_right_rounded,
                          size: AppSizes.iconXs, color: AppColors.subtle),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
