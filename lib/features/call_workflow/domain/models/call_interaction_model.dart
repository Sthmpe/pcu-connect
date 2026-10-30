import 'package:equatable/equatable.dart';

class CallInteractionModel extends Equatable {
  final String contactId;
  final String organizationId;
  final String locationId;
  final String unitId;
  final String? assignmentId;
  final String operatorId;
  final String outcome;
  final String phoneE164;
  final int durationSeconds;
  final String durationBand;
  final String? notes;
  final DateTime? nextFollowUpAt;

  const CallInteractionModel({
    required this.contactId,
    required this.organizationId,
    required this.locationId,
    required this.unitId,
    this.assignmentId,
    required this.operatorId,
    required this.outcome,
    required this.phoneE164,
    required this.durationSeconds,
    required this.durationBand,
    this.notes,
    this.nextFollowUpAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'contactId': contactId,
      'organizationId': organizationId,
      'locationId': locationId,
      'unitId': unitId,
      'assignmentId': assignmentId,
      'operatorId': operatorId,
      'outcome': outcome,
      'phoneE164': phoneE164,
      'durationSeconds': durationSeconds,
      'durationBand': durationBand,
      'notes': notes,
      'nextFollowUpAt': nextFollowUpAt,
      'captureSource': 'manual',
    };
  }

  @override
  List<Object?> get props => [
    contactId,
    organizationId,
    locationId,
    unitId,
    assignmentId,
    operatorId,
    outcome,
    phoneE164,
    durationSeconds,
    durationBand,
    notes,
    nextFollowUpAt,
  ];
}
