import 'package:equatable/equatable.dart';

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
