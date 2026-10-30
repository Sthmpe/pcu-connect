import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Exact Typography Tokens matching PCU Connect Design System (Rubik font)
abstract class AppTextStyles {
  // Page Header (26px, w600)
  static TextStyle get headerTitle => GoogleFonts.rubik(
        fontSize: 26.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  // Page Subtitle (14px, muted blue #B9C4D8)
  static TextStyle get headerSubtitle => GoogleFonts.rubik(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFB9C4D8),
      );

  // Section Header (13px, w600, uppercase, letter-spacing: 0.04em)
  static TextStyle get sectionTitle => GoogleFonts.rubik(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 0.5,
      );

  // Card Guest Name (16px, w600)
  static TextStyle get cardTitle => GoogleFonts.rubik(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  // Metric Tile Big Number (26px, w700)
  static TextStyle get tileNumber => GoogleFonts.rubik(
        fontSize: 26.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      );

  // Metric Tile Label (12px, muted)
  static TextStyle get tileLabel => GoogleFonts.rubik(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      );

  // Status Pill (12px, w600)
  static TextStyle get pill => GoogleFonts.rubik(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      );

  // Filter Chip (14px, w500 / w600)
  static TextStyle chip({required bool isSelected}) => GoogleFonts.rubik(
        fontSize: 14.sp,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF3A455A),
      );

  // Primary Buttons (15px, w700)
  static TextStyle get buttonPrimary => GoogleFonts.rubik(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  // Gold Button Text (15px, w700, Navy)
  static TextStyle get buttonGold => GoogleFonts.rubik(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      );

  // Body text
  static TextStyle get body => GoogleFonts.rubik(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      );

  static TextStyle get bodyMuted => GoogleFonts.rubik(
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      );

  // Form Label (15px, w600)
  static TextStyle get formLabel => GoogleFonts.rubik(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );
}
