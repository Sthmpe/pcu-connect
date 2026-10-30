import 'package:flutter/material.dart';

/// Centralized Color System for PCU Workflow
abstract class AppColors {
  // Brand Primary & Secondary
  static const Color primary = Color(0xFF1E3A8A); // Deep Royal Blue
  static const Color primaryDark = Color(0xFF0F172A); // Midnight Slate
  static const Color primaryLight = Color(0xFF3B82F6); // Vibrant Blue
  static const Color accent = Color(0xFF0D9488); // Deep Teal

  // Neutral Palette
  static const Color background = Color(
    0xFFF8FAFC,
  ); // Off-white surface background
  static const Color surface = Color(0xFFFFFFFF); // Pure white card background
  static const Color surfaceSubtle = Color(
    0xFFF1F5F9,
  ); // Subtle grey background

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Near black for headers
  static const Color textSecondary = Color(
    0xFF475569,
  ); // Slate grey for body text
  static const Color textMuted = Color(0xFF94A3B8); // Muted grey for hints
  static const Color textOnPrimary = Color(
    0xFFFFFFFF,
  ); // White on dark surfaces

  // Lifecycle Stage Colors
  static const Color stageReceived = Color(0xFF6366F1); // Indigo
  static const Color stageAssigned = Color(0xFF3B82F6); // Blue
  static const Color stageContacted = Color(0xFF0284C7); // Light Blue
  static const Color stageReturned = Color(0xFF0D9488); // Teal
  static const Color stageRetained = Color(0xFF10B981); // Green
  static const Color stageIntegrated = Color(0xFF8B5CF6); // Purple
  static const Color stageWorker = Color(0xFFD97706); // Amber / Gold

  // Semantic Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF3B82F6);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color modalBarrier = Color(0x33000000);
}
