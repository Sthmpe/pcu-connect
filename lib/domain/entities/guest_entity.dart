import 'package:equatable/equatable.dart';
import 'follow_up_entry.dart';

enum GuestUrgency { red, amber, green, blue }

class GuestEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String status; // 'New guest' | 'Contacted' | 'Returning' | 'Member' | 'Not interested' | 'Unreachable'
  final int daysSinceVisit;

  /// First visit as a Lagos day ('yyyy-MM-dd'), '' when unknown.
  final String serviceDate;
  final int callCount;
  final int sundayAttendance;
  final int wednesdayAttendance;
  final String teamJoined; // '' | 'Workforce' | 'Evangelism'
  final String lastFeedback;
  final String lastFeedbackDate;

  /// Outcome of the latest call ('' when never called).
  final String lastOutcome;

  /// Lagos day of the latest call ('yyyy-MM-dd'), '' when unknown.
  final String lastCallDate;

  /// 'Male', 'Female', or '' when the sheet's GENDER cell is blank or unclear.
  final String gender;

  /// Lagos days ('yyyy-MM-dd') attended this month, for Road to membership.
  final List<String> sundayDates;
  final List<String> wednesdayDates;

  /// Lagos day the guest became a member ('yyyy-MM-dd'), '' when not (yet) known.
  final String memberSince;
  final int followUpCount;
  final String month; // e.g. 'Oct 2026'
  final String? assignedWorkerName;

  /// Email of the assigned worker ('' when not assigned or not known).
  final String assignedEmail;

  /// Newest first. Only filled by the single guest request.
  final List<FollowUpEntry> history;

  const GuestEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.daysSinceVisit,
    this.serviceDate = '',
    required this.callCount,
    required this.sundayAttendance,
    required this.wednesdayAttendance,
    required this.teamJoined,
    required this.lastFeedback,
    required this.lastFeedbackDate,
    this.lastOutcome = '',
    this.lastCallDate = '',
    this.gender = '',
    this.sundayDates = const [],
    this.wednesdayDates = const [],
    this.memberSince = '',
    required this.followUpCount,
    required this.month,
    this.assignedWorkerName,
    this.assignedEmail = '',
    this.history = const [],
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

  static List<String> _dayList(Object? v) => v is List ? v.map((e) => e.toString()).toList() : const [];

  factory GuestEntity.fromJson(Map<String, dynamic> json) {
    return GuestEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Guest',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'New guest',
      daysSinceVisit: (json['daysSinceVisit'] as num?)?.toInt() ??
          (json['days'] as num?)?.toInt() ??
          0,
      serviceDate: json['serviceDate']?.toString() ?? '',
      callCount: (json['followUps'] as num?)?.toInt() ??
          (json['calls'] as num?)?.toInt() ??
          0,
      sundayAttendance: (json['sundays'] as num?)?.toInt() ??
          (json['sun'] as num?)?.toInt() ??
          0,
      wednesdayAttendance: (json['wednesdays'] as num?)?.toInt() ??
          (json['wed'] as num?)?.toInt() ??
          0,
      teamJoined: json['team']?.toString() ?? '',
      lastFeedback: json['lastFeedback']?.toString() ??
          json['fb']?.toString() ??
          '',
      lastOutcome: json['lastOutcome']?.toString() ?? '',
      lastCallDate: json['lastCallDate']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      sundayDates: _dayList(json['sundayDates']),
      wednesdayDates: _dayList(json['wednesdayDates']),
      memberSince: json['membershipDate']?.toString() ?? '',
      lastFeedbackDate: json['lastFeedbackDate']?.toString() ??
          json['fbDate']?.toString() ??
          '',
      followUpCount: (json['followUps'] as num?)?.toInt() ??
          (json['fu'] as num?)?.toInt() ??
          0,
      month: json['month']?.toString() ?? '',
      assignedEmail: (json['assignedTo']?.toString() ?? '').contains('@') ? json['assignedTo'].toString().trim().toLowerCase() : '',
      assignedWorkerName: json['assignedName']?.toString() ??
          json['assignedWorker']?.toString() ??
          json['assignedTo']?.toString(),
      history: (json['history'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FollowUpEntry.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'status': status,
      'days': daysSinceVisit,
      'serviceDate': serviceDate,
      'calls': callCount,
      'sun': sundayAttendance,
      'wed': wednesdayAttendance,
      'team': teamJoined,
      'fb': lastFeedback,
      'fbDate': lastFeedbackDate,
      'lastOutcome': lastOutcome,
      'lastCallDate': lastCallDate,
      'gender': gender,
      'sundayDates': sundayDates,
      'wednesdayDates': wednesdayDates,
      'membershipDate': memberSince,
      'fu': followUpCount,
      'month': month,
      'assignedWorker': assignedWorkerName,
      'assignedTo': assignedEmail,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        status,
        daysSinceVisit,
        serviceDate,
        callCount,
        sundayAttendance,
        wednesdayAttendance,
        teamJoined,
        lastFeedback,
        lastFeedbackDate,
        lastOutcome,
        lastCallDate,
        gender,
        sundayDates,
        wednesdayDates,
        memberSince,
        followUpCount,
        month,
        assignedWorkerName,
        assignedEmail,
        history,
      ];
}
