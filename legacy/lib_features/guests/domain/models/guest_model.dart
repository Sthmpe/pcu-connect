import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class GuestModel extends Equatable {
  final String id;
  final String organizationId;
  final String locationId;
  final String unitId;
  final String fullName;
  final String phoneOriginal;
  final String phoneE164;
  final String intakeType;
  final String? serviceName;
  final String currentStage;
  final DateTime receivedAt;
  final DateTime? contactedAt;
  final DateTime? returnedAt;
  final DateTime? retainedAt;
  final String? assignedOperatorName;

  const GuestModel({
    required this.id,
    required this.organizationId,
    required this.locationId,
    required this.unitId,
    required this.fullName,
    required this.phoneOriginal,
    required this.phoneE164,
    required this.intakeType,
    this.serviceName,
    required this.currentStage,
    required this.receivedAt,
    this.contactedAt,
    this.returnedAt,
    this.retainedAt,
    this.assignedOperatorName,
  });

  factory GuestModel.fromJson(Map<String, dynamic> json) {
    return GuestModel(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String? ?? '',
      locationId: json['locationId'] as String? ?? '',
      unitId: json['unitId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phoneOriginal: json['phoneOriginal'] as String? ?? '',
      phoneE164: json['phoneE164'] as String? ?? '',
      intakeType: json['intakeType'] as String? ?? 'contact',
      serviceName: json['serviceName'] as String?,
      currentStage: json['currentStage'] as String? ?? 'received',
      receivedAt: _parseTimestamp(json['receivedAt']) ?? DateTime.now(),
      contactedAt: _parseTimestamp(json['contactedAt']),
      returnedAt: _parseTimestamp(json['returnedAt']),
      retainedAt: _parseTimestamp(json['retainedAt']),
      assignedOperatorName: json['assignedOperatorName'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    organizationId,
    locationId,
    unitId,
    fullName,
    phoneOriginal,
    phoneE164,
    intakeType,
    serviceName,
    currentStage,
    receivedAt,
    contactedAt,
    returnedAt,
    retainedAt,
    assignedOperatorName,
  ];

  /// New writes use Firestore [Timestamp] values. String parsing remains only
  /// as a rollout bridge for records created before the naming migration.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }
}
