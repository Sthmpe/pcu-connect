import 'package:flutter/material.dart';
import '../../domain/entities/guest_entity.dart';
import '../constants/app_colors.dart';

/// A color trio for one status: soft background, readable text, and a solid
/// accent for dots, bars and borders.
class StatusTone {
  final Color background;
  final Color foreground;
  final Color accent;

  const StatusTone(this.background, this.foreground, this.accent);

  static const blue = StatusTone(AppColors.blueSoft, AppColors.blueInk, AppColors.blue);
  static const red = StatusTone(AppColors.redSoft, AppColors.redInk, AppColors.red);
  static const amber = StatusTone(AppColors.amberSoft, AppColors.amberInk, AppColors.amber);
  static const green = StatusTone(AppColors.greenSoft, AppColors.greenInk, AppColors.green);
  static const gold = StatusTone(AppColors.goldSoft, AppColors.goldInk, AppColors.gold);
  static const neutral = StatusTone(AppColors.neutralSoft, AppColors.neutralInk, AppColors.subtle);

  /// Guest record status from the sheet.
  static StatusTone forStatus(String status) {
    switch (status) {
      case 'New guest':
        return blue;
      case 'Contacted':
        return amber;
      case 'Returning':
        return green;
      case 'Member':
        return gold;
      case 'Unreachable':
        return red;
      default:
        return neutral;
    }
  }

  /// Follow-up urgency: blue new, red overdue, amber called once, green done.
  static StatusTone forUrgency(GuestUrgency urgency) {
    switch (urgency) {
      case GuestUrgency.blue:
        return blue;
      case GuestUrgency.red:
        return red;
      case GuestUrgency.amber:
        return amber;
      case GuestUrgency.green:
        return green;
    }
  }

  /// Worker standing on the Team screen.
  static StatusTone forStanding(String standing) {
    switch (standing) {
      case 'Outstanding':
        return green;
      case 'On track':
        return blue;
      case 'Behind':
        return amber;
      default:
        return neutral;
    }
  }
}

/// Two-letter initials for any display name.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
