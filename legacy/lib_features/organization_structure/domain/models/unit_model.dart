import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UnitModel extends Equatable {
  final String id;
  final String organizationId;
  final String locationId;
  final String name;
  final String code;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UnitModel({
    required this.id,
    required this.organizationId,
    required this.locationId,
    required this.name,
    required this.code,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory UnitModel.fromJson(String id, Map<String, dynamic> json) {
    return UnitModel(
      id: id,
      organizationId: json['organizationId'] as String? ?? '',
      locationId: json['locationId'] as String? ?? '',
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
    locationId,
    name,
    code,
    active,
    createdAt,
    updatedAt,
  ];
}
