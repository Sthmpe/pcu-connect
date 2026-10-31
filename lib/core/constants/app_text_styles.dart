import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Rubik type scale. Font sizes go through `.sp`, which the app frame caps at
/// 1.0 so text never grows past these values on wide screens.
///
/// body 14 · secondary 12 to 13 · section 16 · screen title 20 · numbers 24 to 28
abstract class AppTextStyles {
  static TextStyle _rubik(double size, FontWeight weight, Color color,
          {double? height, double? letterSpacing}) =>
      GoogleFonts.rubik(
        fontSize: size.sp,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // Headers (on navy)
  static TextStyle get screenTitle =>
      _rubik(20, FontWeight.w600, AppColors.onNavy, height: 1.2);
  static TextStyle get screenSubtitle =>
      _rubik(13, FontWeight.w400, AppColors.onNavyMuted, height: 1.35);
  static TextStyle get detailTitle =>
      _rubik(18, FontWeight.w600, AppColors.onNavy, height: 1.2);

  // Sections and cards
  static TextStyle get sectionTitle =>
      _rubik(16, FontWeight.w600, AppColors.ink, height: 1.25);
  static TextStyle get overline => _rubik(11, FontWeight.w600, AppColors.muted,
      letterSpacing: 0.6, height: 1.2);
  static TextStyle get cardTitle =>
      _rubik(15, FontWeight.w600, AppColors.ink, height: 1.25);
  static TextStyle get itemTitle =>
      _rubik(14, FontWeight.w600, AppColors.ink, height: 1.25);

  // Body
  static TextStyle get body =>
      _rubik(14, FontWeight.w400, AppColors.ink, height: 1.45);
  static TextStyle get bodyStrong =>
      _rubik(14, FontWeight.w500, AppColors.ink, height: 1.4);
  static TextStyle get secondary =>
      _rubik(13, FontWeight.w400, AppColors.muted, height: 1.35);
  static TextStyle get secondaryStrong =>
      _rubik(13, FontWeight.w500, AppColors.inkSoft, height: 1.35);
  static TextStyle get caption =>
      _rubik(12, FontWeight.w400, AppColors.muted, height: 1.3);
  static TextStyle get captionStrong =>
      _rubik(12, FontWeight.w600, AppColors.inkSoft, height: 1.3);

  // Numbers
  static TextStyle get number =>
      _rubik(24, FontWeight.w600, AppColors.ink, height: 1.1);
  static TextStyle get numberLg =>
      _rubik(28, FontWeight.w600, AppColors.ink, height: 1.1);
  static TextStyle get numberSm =>
      _rubik(18, FontWeight.w600, AppColors.ink, height: 1.1);

  // Controls
  static TextStyle get button =>
      _rubik(14, FontWeight.w600, AppColors.onNavy, height: 1.2);
  static TextStyle get buttonSm =>
      _rubik(13, FontWeight.w600, AppColors.onNavy, height: 1.2);
  static TextStyle get chip =>
      _rubik(13, FontWeight.w500, AppColors.inkSoft, height: 1.2);
  static TextStyle get pill =>
      _rubik(11.5, FontWeight.w600, AppColors.neutralInk, height: 1.2);
  static TextStyle get label =>
      _rubik(13, FontWeight.w600, AppColors.inkSoft, height: 1.3);
  static TextStyle get input =>
      _rubik(14, FontWeight.w400, AppColors.ink, height: 1.4);
  static TextStyle get navLabel =>
      _rubik(11, FontWeight.w500, AppColors.muted, height: 1.2);
  static TextStyle get brand =>
      _rubik(24, FontWeight.w700, AppColors.navy, height: 1.15);

  /// Rubik text theme so Material widgets (dialogs, pickers) match.
  static TextTheme get textTheme =>
      GoogleFonts.rubikTextTheme().apply(bodyColor: AppColors.ink);
}
