import 'package:equatable/equatable.dart';

abstract class GuestEvent extends Equatable {
  const GuestEvent();

  @override
  List<Object?> get props => [];
}

class LoadAssignedGuests extends GuestEvent {
  final String operatorId;
  final String? stageFilter;

  const LoadAssignedGuests({required this.operatorId, this.stageFilter});

  @override
  List<Object?> get props => [operatorId, stageFilter];
}

class LoadUnitContacts extends GuestEvent {
  final String unitId;
  final String? stageFilter;

  const LoadUnitContacts({required this.unitId, this.stageFilter});

  @override
  List<Object?> get props => [unitId, stageFilter];
}

class LoadContactDetail extends GuestEvent {
  final String contactId;

  const LoadContactDetail(this.contactId);

  @override
  List<Object?> get props => [contactId];
}
