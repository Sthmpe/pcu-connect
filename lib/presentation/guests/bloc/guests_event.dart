import 'package:equatable/equatable.dart';
import '../../../domain/entities/guest_entity.dart';

abstract class GuestsEvent extends Equatable {
  const GuestsEvent();
  @override
  List<Object?> get props => [];
}

class LoadGuestsEvent extends GuestsEvent {
  final String? month;
  const LoadGuestsEvent({this.month});
  @override
  List<Object?> get props => [month];
}

class ChangeTileFilterEvent extends GuestsEvent {
  final String tile; // 'all' | 'call' | 'fu' | 'mem'
  const ChangeTileFilterEvent(this.tile);
  @override
  List<Object?> get props => [tile];
}

class ChangeChipFilterEvent extends GuestsEvent {
  final String chip; // 'all' | 'call' | 'fu' | 'mem' | 'team'
  const ChangeChipFilterEvent(this.chip);
  @override
  List<Object?> get props => [chip];
}

class SelectMonthEvent extends GuestsEvent {
  final String month;
  const SelectMonthEvent(this.month);
  @override
  List<Object?> get props => [month];
}

/// A fresh list arrived from a live source (Firestore). Sent by the bloc itself.
class GuestsStreamedEvent extends GuestsEvent {
  final String month;
  final List<GuestEntity> guests;
  const GuestsStreamedEvent(this.month, this.guests);
  @override
  List<Object?> get props => [month, guests];
}

/// The live source failed. Sent by the bloc itself.
class GuestsStreamFailedEvent extends GuestsEvent {
  final String month;
  final String message;
  const GuestsStreamFailedEvent(this.month, this.message);
  @override
  List<Object?> get props => [month, message];
}
