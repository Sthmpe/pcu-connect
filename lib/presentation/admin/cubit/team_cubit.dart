import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One worker as shown on the admin Team screens.
class TeamMember extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;
  final int guests;
  final int contacted;
  final int members;
  final int followUps;
  final int teams;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.guests = 0,
    this.contacted = 0,
    this.members = 0,
    this.followUps = 0,
    this.teams = 0,
  });

  String get firstName => name.split(' ').first;

  double get contactRate => guests == 0 ? 0 : contacted / guests;

  String get standing {
    if (!active) return 'Inactive';
    if (guests == 0) return 'On track';
    if (contactRate >= 0.85) return 'Outstanding';
    if (contactRate >= 0.6) return 'On track';
    return 'Behind';
  }

  TeamMember copyWith({bool? active}) => TeamMember(
        id: id,
        name: name,
        email: email,
        role: role,
        active: active ?? this.active,
        guests: guests,
        contacted: contacted,
        members: members,
        followUps: followUps,
        teams: teams,
      );

  @override
  List<Object?> get props =>
      [id, name, email, role, active, guests, contacted, members, followUps, teams];
}

/// Local team list for the admin app. The Team screens are not wired to the
/// Apps Script `team` / `saveWorker` actions yet, so this holds sample data.
class TeamCubit extends Cubit<List<TeamMember>> {
  TeamCubit() : super(_seed);

  static const List<TeamMember> _seed = [
    TeamMember(
      id: 'W001',
      name: 'Grace Ade',
      email: 'grace.ade@example.com',
      role: 'Worker',
      active: true,
      guests: 8,
      contacted: 7,
      members: 3,
      followUps: 14,
      teams: 2,
    ),
    TeamMember(
      id: 'W005',
      name: 'David Olanite',
      email: 'davidolanite0@gmail.com',
      role: 'Worker',
      active: true,
      guests: 6,
      contacted: 5,
      members: 2,
      followUps: 12,
      teams: 2,
    ),
    TeamMember(
      id: 'W003',
      name: 'Tolu Bamidele',
      email: 'tolu@example.com',
      role: 'Worker',
      active: true,
      guests: 5,
      contacted: 4,
      members: 1,
      followUps: 7,
      teams: 1,
    ),
    TeamMember(
      id: 'W004',
      name: 'Samuel Okon',
      email: 'samuel@example.com',
      role: 'Worker',
      active: true,
      guests: 7,
      contacted: 3,
      members: 0,
      followUps: 4,
      teams: 0,
    ),
    TeamMember(
      id: 'W006',
      name: 'Ife Coker',
      email: 'worker.c@example.com',
      role: 'Worker',
      active: false,
    ),
  ];

  /// Active workers first, ranked by members then contacts.
  List<TeamMember> get ranked {
    final list = [...state];
    list.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      final m = b.members.compareTo(a.members);
      if (m != 0) return m;
      return b.contacted.compareTo(a.contacted);
    });
    return list;
  }

  TeamMember? byId(String id) {
    for (final m in state) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool emailExists(String email) =>
      state.any((m) => m.email.toLowerCase() == email.trim().toLowerCase());

  void add({
    required String name,
    required String email,
    required String role,
    required bool active,
  }) {
    final id = 'W${(state.length + 1).toString().padLeft(3, '0')}';
    emit([
      ...state,
      TeamMember(
        id: id,
        name: name.trim(),
        email: email.trim(),
        role: role,
        // Admins never receive guests in the rotation.
        active: active && role == 'Worker',
      ),
    ]);
  }

  void setActive(String id, bool active) {
    emit([for (final m in state) m.id == id ? m.copyWith(active: active) : m]);
  }
}
