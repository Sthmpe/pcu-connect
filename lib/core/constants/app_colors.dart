import 'package:flutter/material.dart';

/// PCU Connect color tokens.
///
/// Navy carries the brand, gold is a restrained accent (selected states and
/// the one primary action per screen), and every status color has a soft
/// background plus a text tone that passes WCAG AA on that background.
abstract class AppColors {
  // Brand
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navyLight = Color(0xFF16305A);
  static const Color navySoft = Color(0xFFEDF1F7);
  static const Color gold = Color(0xFFE3B341);
  static const Color goldSoft = Color(0xFFFFF6DE);
  static const Color goldInk = Color(0xFF7A5800);

  // Surfaces
  static const Color bg = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8F9FB);
  static const Color desktopBackground = Color(0xFFE6EAF0);

  // Text (contrast on white: ink 16:1, inkSoft 8.6:1, muted 4.9:1)
  static const Color ink = Color(0xFF111C2E);
  static const Color inkSoft = Color(0xFF3B4659);
  static const Color muted = Color(0xFF636D7E);
  static const Color subtle = Color(0xFF98A1B0);
  static const Color onNavy = Color(0xFFFFFFFF);
  static const Color onNavyMuted = Color(0xFFB4C0D4);

  // Lines
  static const Color line = Color(0xFFE5E8EE);
  static const Color lineStrong = Color(0xFFD3D8E1);

  // Status: blue = new, red = overdue, amber = called once, green = followed up
  static const Color blue = Color(0xFF2563C9);
  static const Color blueSoft = Color(0xFFEAF1FC);
  static const Color blueInk = Color(0xFF1C4C9C);

  static const Color red = Color(0xFFC0362C);
  static const Color redSoft = Color(0xFFFDEDEB);
  static const Color redInk = Color(0xFFA42A21);

  static const Color amber = Color(0xFFD08A0E);
  static const Color amberSoft = Color(0xFFFFF4E0);
  static const Color amberInk = Color(0xFF8A5300);

  static const Color green = Color(0xFF1E8A4F);
  static const Color greenSoft = Color(0xFFE7F5EC);
  static const Color greenInk = Color(0xFF17663B);

  static const Color neutralSoft = Color(0xFFEEF0F4);
  static const Color neutralInk = Color(0xFF4A5568);

  // Podium medals
  static const Color silver = Color(0xFF9AA4B2);
  static const Color bronze = Color(0xFFB87333);

  // Overlays
  static const Color scrim = Color(0x660B1F3A);
}
