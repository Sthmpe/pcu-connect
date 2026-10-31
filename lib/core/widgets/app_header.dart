import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// Navy page header used by every screen.
///
/// Pass [onBack] for pushed screens, [trailing] for one header action, and
/// [child] to replace the title block (used by the detail screens).
class AppHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final String? backLabel;
  final Widget? child;
  final Widget? bottom;
  final bool rounded;

  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.backLabel,
    this.child,
    this.bottom,
    this.rounded = false,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSizes.gutter,
        topInset + AppSizes.p16,
        AppSizes.gutter,
        rounded ? AppSizes.p20 : AppSizes.p16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyLight],
        ),
        borderRadius: rounded
            ? BorderRadius.vertical(bottom: Radius.circular(AppSizes.radiusXl))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onBack != null) ...[
            HeaderBackButton(onTap: onBack!, label: backLabel ?? 'Back'),
            SizedBox(height: AppSizes.p12),
          ],
          if (child != null)
            child!
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: AppTextStyles.screenTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (subtitle != null) ...[
                        SizedBox(height: AppSizes.p2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.screenSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: AppSizes.p12),
                  trailing!,
                ],
              ],
            ),
          if (bottom != null) ...[
            SizedBox(height: AppSizes.p16),
            bottom!,
          ],
        ],
      ),
    );
  }
}

class HeaderBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const HeaderBackButton({super.key, required this.onTap, this.label = 'Back'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, AppSizes.p4, AppSizes.p8, AppSizes.p4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded,
                  size: AppSizes.iconMd, color: AppColors.onNavyMuted),
              SizedBox(width: AppSizes.p6),
              Text(
                label,
                style: AppTextStyles.secondaryStrong
                    .copyWith(color: AppColors.onNavyMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square gold action used in headers (month picker, add worker).
class HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            height: 38.r,
            constraints: BoxConstraints(minWidth: 38.r),
            padding: EdgeInsets.symmetric(
                horizontal: label == null ? 0 : AppSizes.p12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppSizes.iconMd, color: AppColors.navy),
                if (label != null) ...[
                  SizedBox(width: AppSizes.p4),
                  Text(label!,
                      style: AppTextStyles.buttonSm.copyWith(color: AppColors.navy)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
