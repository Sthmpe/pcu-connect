import 'package:equatable/equatable.dart';

/// A worker with this month's numbers, from the Apps Script `team` action.
class TeamMember extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool active;
  final int guests;
  final int contacted;
  final int followUps;
  final int members;
  final int inTeam;
  final int calledWithin3Days;
  final int points;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    required this.active,
    this.guests = 0,
    this.contacted = 0,
    this.followUps = 0,
    this.members = 0,
    this.inTeam = 0,
    this.calledWithin3Days = 0,
    this.points = 0,
  });

  bool get isAdmin => role == 'Admin' || role == 'HOD';

  String get firstName => name.trim().split(' ').first;

  double get contactRate => guests == 0 ? 0 : contacted / guests;

  /// Display label derived from this month's contact rate.
  String get standing {
    if (!active) return 'Inactive';
    if (isAdmin) return 'Admin';
    if (guests == 0) return 'No guests yet';
    if (contactRate >= 0.85) return 'Outstanding';
    if (contactRate >= 0.6) return 'On track';
    return 'Behind';
  }

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final active = json['active'];
    return TeamMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Worker',
      active: active == true || active?.toString().toLowerCase() == 'yes',
      guests: _int(json['guests']),
      contacted: _int(json['contacted']),
      followUps: _int(json['followUps']),
      members: _int(json['members']),
      inTeam: _int(json['inTeam']),
      calledWithin3Days: _int(json['calledWithin3Days']),
      points: _int(json['points']),
    );
  }

  TeamMember copyWith({bool? active}) => TeamMember(
        id: id,
        name: name,
        email: email,
        phone: phone,
        role: role,
        active: active ?? this.active,
        guests: guests,
        contacted: contacted,
        followUps: followUps,
        members: members,
        inTeam: inTeam,
        calledWithin3Days: calledWithin3Days,
        points: points,
      );

  @override
  List<Object?> get props => [
        id, name, email, phone, role, active, guests, contacted, followUps,
        members, inTeam, calledWithin3Days, points,
      ];
}
