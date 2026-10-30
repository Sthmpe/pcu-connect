import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class LocationModel extends Equatable {
  final String id;
  final String organizationId;
  final String name;
  final String code;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LocationModel({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.code,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory LocationModel.fromJson(String id, Map<String, dynamic> json) {
    return LocationModel(
      id: id,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  static DateTime? _date(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  @override
  List<Object?> get props => [
    id,
    organizationId,
    name,
    code,
    active,
    createdAt,
    updatedAt,
  ];
}
