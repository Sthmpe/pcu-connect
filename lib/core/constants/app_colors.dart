import 'package:flutter/material.dart';

/// Exact Color Tokens matching PCU Connect Design System (base.css)
abstract class AppColors {
  // Brand Palette
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFE3B341);
  static const Color bg = Color(0xFFF3F4F7);
  static const Color ink = Color(0xFF14213A);
  static const Color muted = Color(0xFF5B6678);
  static const Color line = Color(0xFFE3E6EC);
  static const Color surface = Color(0xFFFFFFFF);

  // Status & Semantic Colors
  static const Color green = Color(0xFF1B7A46);
  static const Color amber = Color(0xFFB26A00);
  static const Color red = Color(0xFFB3261E);
  static const Color blue = Color(0xFF2E5A99);

  // Status Pill Backgrounds & Texts
  // Green (.g)
  static const Color pillGreenBg = Color(0xFFE4F4EA);
  static const Color pillGreenText = Color(0xFF1B7A46);

  // Amber (.a)
  static const Color pillAmberBg = Color(0xFFFFF0D6);
  static const Color pillAmberText = Color(0xFF8A5300);

  // Red (.r)
  static const Color pillRedBg = Color(0xFFFBE5E3);
  static const Color pillRedText = Color(0xFFB3261E);

  // Blue (.b)
  static const Color pillBlueBg = Color(0xFFE6EBF4);
  static const Color pillBlueText = Color(0xFF0B1F3A);

  // Gold (.go - Member)
  static const Color pillGoldBg = Color(0xFFFFF3CC);
  static const Color pillGoldText = Color(0xFF8A6A00);

  // Neutral (.n)
  static const Color pillNeutralBg = Color(0xFFE3E6EC);
  static const Color pillNeutralText = Color(0xFF3A455A);

  // Buttons
  static const Color btnCallBg = Color(0xFF0B1F3A);
  static const Color btnWhatsAppBg = Color(0xFFE4F4EA);
  static const Color btnWhatsAppText = Color(0xFF1B7A46);

  // Desktop Shell Background
  static const Color desktopBackground = Color(0xFFD9DDE5);
}
