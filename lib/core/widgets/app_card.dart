import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// White surface with a hairline border and a soft shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double? radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? AppSizes.radiusLg);
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: r,
        border: Border.all(color: borderColor ?? AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(
            padding: padding ?? EdgeInsets.all(AppSizes.p16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Section title with an optional count and trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          EdgeInsets.only(top: AppSizes.p8, bottom: AppSizes.p10),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          if (count != null) ...[
            SizedBox(width: AppSizes.p8),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.p6, vertical: AppSizes.p2),
              decoration: BoxDecoration(
                color: AppColors.neutralSoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text('$count', style: AppTextStyles.captionStrong),
            ),
          ],
          const Spacer(),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.p4, vertical: AppSizes.p2),
                child: Text(
                  actionLabel!,
                  style: AppTextStyles.secondaryStrong
                      .copyWith(color: AppColors.blueInk),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Initials avatar.
class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color background;
  final Color foreground;
  final Color? ring;

  const AppAvatar({
    super.key,
    required this.initials,
    required this.size,
    this.background = AppColors.navySoft,
    this.foreground = AppColors.navy,
    this.ring,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 2),
      ),
      child: Text(
        initials,
        style: AppTextStyles.itemTitle.copyWith(
          color: foreground,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Rounded, animated progress bar.
class AppProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double? height;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.green,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? AppSizes.p6;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: SizedBox(
        height: h,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: AppDurations.slow,
          curve: AppDurations.curve,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: h,
            backgroundColor: AppColors.neutralSoft,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    );
  }
}

/// Label on the left, value on the right. Used in detail cards.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.p6),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: AppColors.muted),
          SizedBox(width: AppSizes.p10),
          Expanded(child: Text(label, style: AppTextStyles.secondary)),
          Text(
            value,
            style: AppTextStyles.bodyStrong
                .copyWith(color: valueColor ?? AppColors.ink),
          ),
        ],
      ),
    );
  }
}
