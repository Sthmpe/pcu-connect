import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Spacing, radii and component sizes. ScreenUtil is configured from the
/// phone frame width only (see ResponsiveWebShell), so `.r` scales evenly and
/// stays close to 1.0 on every screen.
abstract class AppSizes {
  // Spacing (4pt grid)
  static double get p2 => 2.r;
  static double get p4 => 4.r;
  static double get p6 => 6.r;
  static double get p8 => 8.r;
  static double get p10 => 10.r;
  static double get p12 => 12.r;
  static double get p16 => 16.r;
  static double get p20 => 20.r;
  static double get p24 => 24.r;
  static double get p32 => 32.r;
  static double get p40 => 40.r;

  /// Horizontal page gutter
  static double get gutter => 16.r;

  // Icons
  static double get iconXs => 14.r;
  static double get iconSm => 16.r;
  static double get iconMd => 20.r;
  static double get iconLg => 24.r;

  // Radii
  static double get radiusSm => 8.r;
  static double get radiusMd => 12.r;
  static double get radiusLg => 16.r;
  static double get radiusXl => 20.r;
  static const double radiusFull = 999;

  // Components
  static double get buttonHeight => 48.r;
  static double get buttonHeightSm => 34.r;
  static double get inputHeight => 46.r;
  static double get chipHeight => 32.r;
  static double get navBarHeight => 64.r;
  static double get avatarSm => 32.r;
  static double get avatarMd => 40.r;
  static double get avatarLg => 52.r;
  static double get iconButton => 36.r;

  // Phone frame used on wide screens
  static const double frameWidth = 400;
  static const double frameMaxHeight = 880;
  static const double frameRadius = 28;
  static const Size designSize = Size(390, 844);
}

/// Soft, layered shadows. Cards rely on a hairline border plus a very light
/// shadow rather than heavy elevation.
abstract class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get frame => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.18),
          blurRadius: 60,
          offset: const Offset(0, 24),
        ),
      ];

  static List<BoxShadow> get bar => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ];
}

/// Motion: short and subtle.
abstract class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;
}
