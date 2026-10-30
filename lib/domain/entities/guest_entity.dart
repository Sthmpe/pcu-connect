import 'package:equatable/equatable.dart';

enum GuestUrgency { red, amber, green, blue }

class GuestEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String status; // 'New guest' | 'Contacted' | 'Returning' | 'Member' | 'Not interested' | 'Unreachable'
  final int daysSinceVisit;
  final int callCount;
  final int sundayAttendance;
  final int wednesdayAttendance;
  final String teamJoined; // '' | 'Workforce' | 'Evangelism'
  final String lastFeedback;
  final String lastFeedbackDate;
  final int followUpCount;
  final String month; // e.g. 'Oct 2026'
  final String? assignedWorkerName;

  const GuestEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.daysSinceVisit,
    required this.callCount,
    required this.sundayAttendance,
    required this.wednesdayAttendance,
    required this.teamJoined,
    required this.lastFeedback,
    required this.lastFeedbackDate,
    required this.followUpCount,
    required this.month,
    this.assignedWorkerName,
  });

  /// Computed performance urgency color matching PCU Connect rules:
  /// - Red: Not called after 3 days
  /// - Blue: New guest, within 3 days, not yet called
  /// - Amber: Called once, needs follow up
  /// - Green: First call within 3 days or followed up 2+ times
  GuestUrgency get urgency {
    if (callCount == 0) {
      return daysSinceVisit > 3 ? GuestUrgency.red : GuestUrgency.blue;
    } else if (callCount == 1) {
      return GuestUrgency.amber;
    } else {
      return GuestUrgency.green;
    }
  }

  String get progressText {
    if (callCount == 0) {
      return daysSinceVisit > 3
          ? 'Not called · $daysSinceVisit days'
          : 'Call within 3 days';
    } else if (callCount == 1) {
      return 'Called once · follow up';
    } else {
      return 'Followed up';
    }
  }

  /// Initials for the guest avatar
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Clean Nigerian WhatsApp URL (wa.me/234...)
  String get whatsAppUrl {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    return 'https://wa.me/234$last10';
  }

  /// Phone call tel: link
  String get telUrl {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    return 'tel:$cleaned';
  }

  factory GuestEntity.fromJson(Map<String, dynamic> json) {
    return GuestEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Guest',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'New guest',
      daysSinceVisit: (json['days'] as num?)?.toInt() ?? 0,
      callCount: (json['calls'] as num?)?.toInt() ?? 0,
      sundayAttendance: (json['sun'] as num?)?.toInt() ?? 0,
      wednesdayAttendance: (json['wed'] as num?)?.toInt() ?? 0,
      teamJoined: json['team']?.toString() ?? '',
      lastFeedback: json['fb']?.toString() ?? '',
      lastFeedbackDate: json['fbDate']?.toString() ?? '',
      followUpCount: (json['fu'] as num?)?.toInt() ?? 0,
      month: json['month']?.toString() ?? '',
      assignedWorkerName: json['assignedWorker']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'status': status,
      'days': daysSinceVisit,
      'calls': callCount,
      'sun': sundayAttendance,
      'wed': wednesdayAttendance,
      'team': teamJoined,
      'fb': lastFeedback,
      'fbDate': lastFeedbackDate,
      'fu': followUpCount,
      'month': month,
      'assignedWorker': assignedWorkerName,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        status,
        daysSinceVisit,
        callCount,
        sundayAttendance,
        wednesdayAttendance,
        teamJoined,
        lastFeedback,
        lastFeedbackDate,
        followUpCount,
        month,
        assignedWorkerName,
      ];
}
