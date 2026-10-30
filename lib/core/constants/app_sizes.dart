import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Centralized ScreenUtil Dimension & Spacing System
abstract class AppSizes {
  // Spacing & Padding
  static double get p4 => 4.r;
  static double get p8 => 8.r;
  static double get p12 => 12.r;
  static double get p16 => 16.r;
  static double get p20 => 20.r;
  static double get p24 => 24.r;
  static double get p32 => 32.r;
  static double get p40 => 40.r;
  static double get p48 => 48.r;

  // Icon Sizes
  static double get iconSm => 16.r;
  static double get iconMd => 24.r;
  static double get iconLg => 32.r;
  static double get iconXl => 48.r;

  // Border Radii
  static double get radiusSm => 6.r;
  static double get radiusMd => 12.r;
  static double get radiusLg => 16.r;
  static double get radiusXl => 24.r;
  static double get radiusFull => 999.r;

  // Component Specific Dimensions
  static double get buttonHeight => 52.h;
  static double get inputHeight => 52.h;
  static double get appBarHeight => 56.h;
  static double get cardElevation => 2.r;
}
