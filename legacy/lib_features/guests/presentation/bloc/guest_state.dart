import 'package:equatable/equatable.dart';
import '../../domain/models/guest_model.dart';

abstract class GuestState extends Equatable {
  const GuestState();

  @override
  List<Object?> get props => [];
}

class GuestInitial extends GuestState {
  const GuestInitial();
}

class GuestLoading extends GuestState {
  const GuestLoading();
}

class GuestLoaded extends GuestState {
  final List<GuestModel> guests;

  const GuestLoaded(this.guests);

  @override
  List<Object?> get props => [guests];
}

class GuestFailure extends GuestState {
  final String errorMessage;

  const GuestFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class GuestDetailLoading extends GuestState {
  const GuestDetailLoading();
}

class GuestDetailLoaded extends GuestState {
  final GuestModel guest;

  const GuestDetailLoaded(this.guest);

  @override
  List<Object?> get props => [guest];
}

class GuestDetailFailure extends GuestState {
  final String errorMessage;

  const GuestDetailFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
