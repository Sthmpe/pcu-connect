import 'package:equatable/equatable.dart';

class WorkerUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'Worker' | 'Admin' | 'HOD'
  final bool active;

  const WorkerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.active,
  });

  bool get isAdmin => role == 'Admin' || role == 'HOD';

  factory WorkerUser.fromJson(Map<String, dynamic> json) {
    return WorkerUser(
      id: json['ID']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? 'Worker',
      email: json['Email']?.toString() ?? json['email']?.toString() ?? '',
      phone: json['Phone']?.toString() ?? json['phone']?.toString() ?? '',
      role: json['Role']?.toString() ?? json['role']?.toString() ?? 'Worker',
      active: (json['Active']?.toString().toLowerCase() == 'yes') ||
          (json['active']?.toString().toLowerCase() == 'yes') ||
          (json['Active'] == true) ||
          (json['active'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'active': active ? 'Yes' : 'No',
    };
  }

  @override
  List<Object?> get props => [id, name, email, phone, role, active];
}
