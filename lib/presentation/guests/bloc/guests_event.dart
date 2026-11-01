import 'package:equatable/equatable.dart';
import '../../../domain/entities/guest_entity.dart';

abstract class GuestsEvent extends Equatable {
  const GuestsEvent();
  @override
  List<Object?> get props => [];
}

/// A screen needs these months. Months already loaded or loading are left
/// alone; the others are fetched (Apps Script) or watched live (Firestore).
/// Watching never changes any screen's selected month.
class WatchMonthsEvent extends GuestsEvent {
  final List<String> months;
  const WatchMonthsEvent(this.months);
  @override
  List<Object?> get props => [months];
}

/// Fetch these months again (all loaded months when empty). Live months
/// (Firestore) are already current and are skipped.
class RefreshMonthsEvent extends GuestsEvent {
  final List<String> months;
  const RefreshMonthsEvent([this.months = const []]);
  @override
  List<Object?> get props => [months];
}

/// Sign-in or sign-out: drop every month and stop every live listener, so
/// one person never sees another person's guests.
class ResetGuestsEvent extends GuestsEvent {
  const ResetGuestsEvent();
}

/// A fresh list arrived from a live source (Firestore). Sent by the bloc itself.
class GuestsStreamedEvent extends GuestsEvent {
  final String month;
  final List<GuestEntity> guests;
  const GuestsStreamedEvent(this.month, this.guests);
  @override
  List<Object?> get props => [month, guests];
}

/// The live source for a month failed. Sent by the bloc itself.
class GuestsStreamFailedEvent extends GuestsEvent {
  final String month;
  final String message;
  const GuestsStreamFailedEvent(this.month, this.message);
  @override
  List<Object?> get props => [month, message];
}
