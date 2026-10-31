import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

enum AppButtonVariant { primary, accent, whatsapp, tonal, outline, danger }

enum AppButtonSize { regular, small }

/// The one button used across the app.
///
/// primary: navy (Call, Save on admin forms) · accent: gold (the main action
/// of a screen) · whatsapp: green tonal · tonal: soft navy · outline: neutral
/// border · danger: red outline.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.isLoading = false,
    this.expand = true,
  });

  ({Color bg, Color fg, Color? border}) get _colors {
    switch (variant) {
      case AppButtonVariant.primary:
        return (bg: AppColors.navy, fg: AppColors.onNavy, border: null);
      case AppButtonVariant.accent:
        return (bg: AppColors.gold, fg: AppColors.navy, border: null);
      case AppButtonVariant.whatsapp:
        return (bg: AppColors.greenSoft, fg: AppColors.greenInk, border: null);
      case AppButtonVariant.tonal:
        return (bg: AppColors.navySoft, fg: AppColors.navy, border: null);
      case AppButtonVariant.outline:
        return (
          bg: AppColors.surface,
          fg: AppColors.inkSoft,
          border: AppColors.lineStrong
        );
      case AppButtonVariant.danger:
        return (bg: AppColors.surface, fg: AppColors.redInk, border: AppColors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final small = size == AppButtonSize.small;
    final height = small ? AppSizes.buttonHeightSm : AppSizes.buttonHeight;
    final radius = BorderRadius.circular(
        small ? AppSizes.radiusFull : AppSizes.radiusMd);
    final enabled = onPressed != null && !isLoading;
    final textStyle = (small ? AppTextStyles.buttonSm : AppTextStyles.button)
        .copyWith(color: c.fg);

    final content = isLoading
        ? SizedBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: c.fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: AppSizes.p8),
              ] else if (icon != null) ...[
                Icon(icon,
                    size: small ? AppSizes.iconSm : AppSizes.iconMd,
                    color: c.fg),
                SizedBox(width: small ? AppSizes.p6 : AppSizes.p8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return AnimatedOpacity(
      duration: AppDurations.fast,
      opacity: enabled || isLoading ? 1 : 0.5,
      child: Material(
        color: c.bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: c.border == null
              ? BorderSide.none
              : BorderSide(color: c.border!, width: 1.2),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Container(
            height: height,
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(
                horizontal: small ? AppSizes.p12 : AppSizes.p16),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Bottom action bar that holds a screen's primary button.
class BottomActionBar extends StatelessWidget {
  final Widget child;

  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.gutter,
        AppSizes.p12,
        AppSizes.gutter,
        AppSizes.p12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: AppShadows.bar,
      ),
      child: child,
    );
  }
}
