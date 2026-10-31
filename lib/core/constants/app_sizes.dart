import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// 8px spacing scale (4 is the half step), two radii, 48px touch targets.
/// ScreenUtil is configured from the phone frame width (ResponsiveWebShell),
/// so `.r` stays close to 1.0 everywhere.
abstract class AppSizes {
  static double get s4 => 4.r;
  static double get s8 => 8.r;
  static double get s16 => 16.r;
  static double get s24 => 24.r;
  static double get s32 => 32.r;
  static double get s40 => 40.r;
  static double get s48 => 48.r;

  /// Page side padding
  static double get gutter => 24.r;

  // Radii: 12 for controls, 20 for cards and sheets
  static double get radiusSm => 12.r;
  static double get radiusLg => 20.r;
  static const double radiusFull = 999;

  // Components
  static double get touch => 48.r;
  static double get buttonHeight => 48.r;
  static double get iconButton => 40.r;
  static double get chipHeight => 32.r;
  static double get navBarHeight => 64.r;
  static double get topBarHeight => 56.r;

  // Icons
  static double get iconSm => 16.r;
  static double get iconMd => 20.r;
  static double get iconLg => 24.r;

  // Avatars
  static double get avatarSm => 32.r;
  static double get avatarMd => 40.r;
  static double get avatarLg => 64.r;

  // Phone frame on wide screens
  static const double frameWidth = 400;
  static const double frameMaxHeight = 880;
  static const double frameRadius = 32;
  static const Size designSize = Size(390, 844);
}

/// Cards use a soft shadow and no border.
abstract class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Lighter lift for small controls (chips, pills) so rows of them stay clean.
  static List<BoxShadow> get control => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.14),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get frame => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.16),
          blurRadius: 64,
          offset: const Offset(0, 24),
        ),
      ];
}

/// Motion: short and subtle.
abstract class AppDurations {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 600);
  static const Curve curve = Curves.easeOutCubic;
}
