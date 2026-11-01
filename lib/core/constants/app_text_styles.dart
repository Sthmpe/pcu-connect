import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Rubik, four sizes and two weights:
/// display 26 · title 18 · body 14 · caption 12, regular (400) and semibold (600).
/// The font ships with the app (assets/fonts), so nothing is fetched at startup.
abstract class AppTextStyles {
  static const String fontFamily = 'Rubik';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semibold = FontWeight.w600;

  static TextStyle _rubik(double size, FontWeight weight, Color color, double height) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size.sp,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: size >= 18 ? -0.2 : 0,
      ).copyWith(leadingDistribution: TextLeadingDistribution.even);

  /// Rubik's metrics sit text slightly off centre. Spreading the line's
  /// leading evenly and ignoring it above the first and below the last line
  /// puts glyphs in the true vertical centre of capsules and buttons.
  static const TextHeightBehavior centeredHeight = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Text inside pills, chips, buttons, tabs and badges.
  static TextStyle centered(TextStyle s) =>
      s.copyWith(height: 1.2, leadingDistribution: TextLeadingDistribution.even);

  static TextStyle get display => _rubik(26, semibold, AppColors.ink, 1.15);
  static TextStyle get title => _rubik(18, semibold, AppColors.ink, 1.25);
  static TextStyle get body => _rubik(14, regular, AppColors.ink, 1.45);
  static TextStyle get bodyStrong => _rubik(14, semibold, AppColors.ink, 1.35);
  static TextStyle get bodyMuted => _rubik(14, regular, AppColors.muted, 1.45);
  static TextStyle get caption => _rubik(12, regular, AppColors.muted, 1.35);
  static TextStyle get captionStrong => _rubik(12, semibold, AppColors.inkSoft, 1.3);
  static TextStyle get button => _rubik(14, semibold, AppColors.navy, 1.2);

  /// Rubik text theme so Material widgets (dialogs, pickers) match.
  static TextTheme get textTheme =>
      ThemeData.light().textTheme.apply(fontFamily: fontFamily, bodyColor: AppColors.ink);
}
