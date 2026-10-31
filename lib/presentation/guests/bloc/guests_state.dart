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
  final bool isFromCache;
  final bool isRefreshing;

  const GuestsLoadedState({
    required this.allGuests,
    required this.selectedMonth,
    this.tileFilter = 'all',
    this.chipFilter = 'all',
    this.isFromCache = false,
    this.isRefreshing = false,
  });

  /// Guests whose first visit was in the selected month.
  List<GuestEntity> get monthGuests =>
      allGuests.where((g) => g.month == selectedMonth).toList();

  /// Number of this month's guests matching a filter key
  /// ('all' | 'call' | 'fu' | 'mem' | 'team').
  int countFor(String filter) {
    final list = monthGuests;
    switch (filter) {
      case 'call':
        return list.where((g) => g.callCount == 0).length;
      case 'fu':
        return list.where((g) => g.callCount > 0).length;
      case 'mem':
        return list.where((g) => g.status == 'Member').length;
      case 'team':
        return list.where((g) => g.teamJoined.isNotEmpty).length;
      default:
        return list.length;
    }
  }

  /// The guest who has waited longest without a call, if any.
  GuestEntity? get nextToCall {
    final waiting = monthGuests.where((g) => g.callCount == 0).toList()
      ..sort((a, b) => b.daysSinceVisit.compareTo(a.daysSinceVisit));
    return waiting.isEmpty ? null : waiting.first;
  }

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
    bool? isFromCache,
    bool? isRefreshing,
  }) {
    return GuestsLoadedState(
      allGuests: allGuests ?? this.allGuests,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      tileFilter: tileFilter ?? this.tileFilter,
      chipFilter: chipFilter ?? this.chipFilter,
      isFromCache: isFromCache ?? this.isFromCache,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
        allGuests,
        selectedMonth,
        tileFilter,
        chipFilter,
        isFromCache,
        isRefreshing,
      ];
}

class GuestsFailureState extends GuestsState {
  final String message;
  const GuestsFailureState(this.message);
  @override
  List<Object?> get props => [message];
}
