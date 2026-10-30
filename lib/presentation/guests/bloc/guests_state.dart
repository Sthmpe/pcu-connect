import 'package:equatable/equatable.dart';
import '../../../domain/entities/guest_entity.dart';

abstract class GuestsState extends Equatable {
  const GuestsState();
  @override
  List<Object?> get props => [];
}

class GuestsInitialState extends GuestsState {}

class GuestsLoadingState extends GuestsState {}

class GuestsLoadedState extends GuestsState {
  final List<GuestEntity> allGuests;
  final String selectedMonth;
  final String tileFilter; // 'all' | 'call' | 'fu' | 'mem'
  final String chipFilter; // 'all' | 'call' | 'fu' | 'mem' | 'team'

  const GuestsLoadedState({
    required this.allGuests,
    required this.selectedMonth,
    this.tileFilter = 'all',
    this.chipFilter = 'all',
  });

  // Today Tab computed metrics
  int get todayCallCount =>
      allGuests.where((g) => g.month == selectedMonth && g.callCount == 0).length;

  int get todayFollowedUpCount =>
      allGuests.where((g) => g.month == selectedMonth && g.callCount > 0).length;

  int get todayMemberCount => allGuests
      .where((g) => g.month == selectedMonth && g.status == 'Member')
      .length;

  // Filtered list for "Today" tab
  List<GuestEntity> get todayFilteredGuests {
    final list = allGuests.where((g) => g.month == selectedMonth).toList();
    List<GuestEntity> filtered;
    switch (tileFilter) {
      case 'call':
        filtered = list.where((g) => g.callCount == 0).toList();
        break;
      case 'fu':
        filtered = list.where((g) => g.callCount > 0).toList();
        break;
      case 'mem':
        filtered = list.where((g) => g.status == 'Member').toList();
        break;
      default:
        filtered = list;
    }

    // Sort order matching PCU Connect: (calls ascending, then days descending)
    filtered.sort((a, b) {
      final callDiff = a.callCount.compareTo(b.callCount);
      if (callDiff != 0) return callDiff;
      return b.daysSinceVisit.compareTo(a.daysSinceVisit);
    });
    return filtered;
  }

  // Filtered list for "My Guests" tab
  List<GuestEntity> get myGuestsFiltered {
    final list = allGuests.where((g) => g.month == selectedMonth).toList();
    switch (chipFilter) {
      case 'call':
        return list.where((g) => g.callCount == 0).toList();
      case 'fu':
        return list.where((g) => g.callCount > 0).toList();
      case 'mem':
        return list.where((g) => g.status == 'Member').toList();
      case 'team':
        return list.where((g) => g.teamJoined.isNotEmpty).toList();
      default:
        return list;
    }
  }

  GuestsLoadedState copyWith({
    List<GuestEntity>? allGuests,
    String? selectedMonth,
    String? tileFilter,
    String? chipFilter,
  }) {
    return GuestsLoadedState(
      allGuests: allGuests ?? this.allGuests,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      tileFilter: tileFilter ?? this.tileFilter,
      chipFilter: chipFilter ?? this.chipFilter,
    );
  }

  @override
  List<Object?> get props =>
      [allGuests, selectedMonth, tileFilter, chipFilter];
}

class GuestsFailureState extends GuestsState {
  final String message;
  const GuestsFailureState(this.message);
  @override
  List<Object?> get props => [message];
}
