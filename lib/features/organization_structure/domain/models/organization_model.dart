import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class OrganizationModel extends Equatable {
  final String id;
  final String name;
  final String code;
  final bool active;
  final Map<String, String> terminology;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrganizationModel({
    required this.id,
    required this.name,
    required this.code,
    required this.active,
    this.terminology = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory OrganizationModel.fromJson(String id, Map<String, dynamic> json) {
    return OrganizationModel(
      id: id,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      terminology: Map<String, String>.from(
        json['terminology'] as Map? ?? const {},
      ),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  static DateTime? _date(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  @override
  List<Object?> get props => [
    id,
    name,
    code,
    active,
    terminology,
    createdAt,
    updatedAt,
  ];
}
