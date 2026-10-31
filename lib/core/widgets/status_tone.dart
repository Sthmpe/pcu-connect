import 'package:flutter/material.dart';
import '../../domain/entities/guest_entity.dart';
import '../constants/app_colors.dart';

/// A color trio for one status: soft tint, readable text, solid dot.
class StatusTone {
  final Color background;
  final Color foreground;
  final Color dot;

  const StatusTone(this.background, this.foreground, this.dot);

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

  /// Worker standing on the Team screens.
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

/// Short, friendly line for a guest's follow-up state.
String guestProgressLine(GuestEntity g) {
  if (g.callCount == 0) {
    if (g.daysSinceVisit > 3) return 'Waiting ${g.daysSinceVisit} days for a call';
    if (g.daysSinceVisit <= 0) return 'Visited today, call soon';
    return 'Visited ${g.daysSinceVisit} ${g.daysSinceVisit == 1 ? 'day' : 'days'} ago';
  }
  if (g.callCount == 1) return 'Called once, follow up again';
  if (g.status == 'Member') return 'Member';
  return 'Followed up ${g.callCount} times';
}

/// Two-letter initials for any display name.
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String firstNameOf(String name) => name.trim().split(RegExp(r'\s+')).first;
