import 'package:equatable/equatable.dart';

class WorkerModel extends Equatable {
  final String membershipId;
  final String profileId;
  final String fullName;
  final String role;
  final String availabilityStatus;
  final int openWorkloadCount;
  final DateTime? lastAssignedAt;

  const WorkerModel({
    required this.membershipId,
    required this.profileId,
    required this.fullName,
    required this.role,
    required this.availabilityStatus,
    required this.openWorkloadCount,
    this.lastAssignedAt,
  });

  factory WorkerModel.fromJson(
    Map<String, dynamic> json, {
    int openWorkload = 0,
  }) {
    final profileData = json['profiles'] as Map<String, dynamic>? ?? {};
    return WorkerModel(
      membershipId: json['id'] as String,
      profileId: json['profile_id'] as String,
      fullName: profileData['full_name'] as String? ?? 'Worker',
      role: json['role'] as String? ?? 'worker',
      availabilityStatus: json['availability_status'] as String? ?? 'active',
      openWorkloadCount: openWorkload,
      lastAssignedAt: json['last_assigned_at'] != null
          ? DateTime.parse(json['last_assigned_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    membershipId,
    profileId,
    fullName,
    role,
    availabilityStatus,
    openWorkloadCount,
    lastAssignedAt,
  ];
}
