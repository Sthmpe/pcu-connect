import 'package:equatable/equatable.dart';

/// The display-label layer over the platform's neutral internal concepts.
/// Internal code, Firestore field names, and Capability strings never
/// change (`organizationOwner`, `unit`, `operator`, `contact` etc.) - only
/// what a screen SHOWS the user changes per organization. This is what
/// lets the same codebase read as "PCU Workflow" (Pastor/HOD/Worker/Guest)
/// for a church and something entirely different for another org, with
/// zero code changes.
///
/// Defaults below are the PCU Workflow labels - the first configuration,
/// not a special case baked into the type itself.
class AppTerminology extends Equatable {
  final String organization; // Church
  final String organizationPlural; // Churches
  final String organizationOwner; // Pastor
  final String location; // Campus
  final String unit; // Pastoral Care Unit
  final String unitManager; // HOD
  final String operatorLabel; // Worker
  final String operatorLabelPlural; // Workers
  final String contact; // Guest
  final String contactPlural; // Guests
  final String journey; // Guest Journey

  const AppTerminology({
    this.organization = 'Church',
    this.organizationPlural = 'Churches',
    this.organizationOwner = 'Pastor',
    this.location = 'Campus',
    this.unit = 'Pastoral Care Unit',
    this.unitManager = 'HOD',
    this.operatorLabel = 'Worker',
    this.operatorLabelPlural = 'Workers',
    this.contact = 'Guest',
    this.contactPlural = 'Guests',
    this.journey = 'Guest Journey',
  });

  static const defaults = AppTerminology();

  /// Merges only the keys an organization actually overrides - any key it
  /// doesn't set falls back to the PCU Workflow default rather than going
  /// blank, so a partially-configured organization never shows an empty label.
  factory AppTerminology.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return defaults;
    return AppTerminology(
      organization: json['organization'] as String? ?? defaults.organization,
      organizationPlural:
          json['organizationPlural'] as String? ?? defaults.organizationPlural,
      organizationOwner:
          json['organizationOwner'] as String? ?? defaults.organizationOwner,
      location: json['location'] as String? ?? defaults.location,
      unit: json['unit'] as String? ?? defaults.unit,
      unitManager: json['unitManager'] as String? ?? defaults.unitManager,
      operatorLabel: json['operator'] as String? ?? defaults.operatorLabel,
      operatorLabelPlural:
          json['operatorPlural'] as String? ?? defaults.operatorLabelPlural,
      contact: json['contact'] as String? ?? defaults.contact,
      contactPlural: json['contactPlural'] as String? ?? defaults.contactPlural,
      journey: json['journey'] as String? ?? defaults.journey,
    );
  }

  @override
  List<Object?> get props => [
    organization,
    organizationPlural,
    organizationOwner,
    location,
    unit,
    unitManager,
    operatorLabel,
    operatorLabelPlural,
    contact,
    contactPlural,
    journey,
  ];
}
