import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.navy;
    final effectiveText = textColor ?? Colors.white;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: effectiveBg,
        minimumSize: Size.fromHeight(AppSizes.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      child: isLoading
          ? SizedBox(
              height: AppSizes.iconMd,
              width: AppSizes.iconMd,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: effectiveText,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppSizes.iconSm, color: effectiveText),
                  SizedBox(width: AppSizes.p8),
                ],
                Text(
                  text,
                  style: AppTextStyles.buttonPrimary.copyWith(
                    color: effectiveText,
                  ),
                ),
              ],
            ),
    );
  }
}
