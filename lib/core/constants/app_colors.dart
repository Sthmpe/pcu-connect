import 'package:flutter/material.dart';

/// PCU Connect color tokens.
///
/// Neutral surfaces carry the content, navy gives structure, and gold is kept
/// for the primary action and the selected state only. Status colors come as
/// a small solid dot plus a soft tint with readable text.
abstract class AppColors {
  // Brand
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navyRaised = Color(0xFF162C4D);
  static const Color navySoft = Color(0xFFEEF1F6);
  static const Color gold = Color(0xFFE3B341);
  static const Color goldSoft = Color(0xFFFBF3DD);
  static const Color goldInk = Color(0xFF6E5200);

  // Surfaces
  static const Color bg = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color sunken = Color(0xFFF1F3F6);
  static const Color desktopBackground = Color(0xFFE9ECF1);

  // Text. Contrast on white: ink 17:1, inkSoft 9:1, muted 4.9:1.
  static const Color ink = Color(0xFF0E1726);
  static const Color inkSoft = Color(0xFF3D4756);
  static const Color muted = Color(0xFF667085);
  static const Color subtle = Color(0xFFA0A8B4);
  static const Color onNavy = Color(0xFFFFFFFF);
  static const Color onNavyMuted = Color(0xFFAFBCD0);

  // Lines
  static const Color line = Color(0xFFE6E9EE);
  static const Color lineStrong = Color(0xFFD5DAE1);

  // Status: blue new, red overdue, amber called once, green followed up
  static const Color blue = Color(0xFF2F6FDB);
  static const Color blueSoft = Color(0xFFEBF2FD);
  static const Color blueInk = Color(0xFF1D4FA8);

  static const Color red = Color(0xFFD14343);
  static const Color redSoft = Color(0xFFFDEEEE);
  static const Color redInk = Color(0xFFA62D2D);

  static const Color amber = Color(0xFFD9930D);
  static const Color amberSoft = Color(0xFFFDF4E2);
  static const Color amberInk = Color(0xFF875800);

  static const Color green = Color(0xFF1F9D5C);
  static const Color greenSoft = Color(0xFFE8F6EE);
  static const Color greenInk = Color(0xFF16703F);

  static const Color neutralSoft = Color(0xFFEEF0F3);
  static const Color neutralInk = Color(0xFF4B5565);

  // Top three
  static const Color silver = Color(0xFFB4BCC8);
  static const Color bronze = Color(0xFFC08A5B);

  static const Color scrim = Color(0x590B1F3A);
}
