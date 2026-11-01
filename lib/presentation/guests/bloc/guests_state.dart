import 'package:equatable/equatable.dart';
import '../../../domain/entities/guest_entity.dart';

enum MonthStatus { loading, loaded, failed }

/// One month of guests in the cache.
class MonthGuests extends Equatable {
  final MonthStatus status;
  final List<GuestEntity> guests;

  /// Shown from the device copy because the latest fetch failed.
  final bool fromCache;
  final bool refreshing;
  final String? message;

  const MonthGuests({
    required this.status,
    this.guests = const [],
    this.fromCache = false,
    this.refreshing = false,
    this.message,
  });

  bool get hasData => status == MonthStatus.loaded || guests.isNotEmpty;

  @override
  List<Object?> get props => [status, guests, fromCache, refreshing, message];
}

/// Guests the app has loaded, by month ('2026-10'). It holds no selected
/// month: every screen keeps its own (GuestsFilterCubit, DashboardCubit,
/// Today's rule), so changing one screen never moves another.
class GuestsState extends Equatable {
  final Map<String, MonthGuests> months;

  const GuestsState({this.months = const {}});

  MonthGuests? of(String month) => months[month];

  List<GuestEntity> guestsOf(String month) => months[month]?.guests ?? const [];

  /// Guests of several months, each guest once.
  List<GuestEntity> guestsIn(Iterable<String> keys) {
    final seen = <String>{};
    return [
      for (final m in keys)
        for (final g in guestsOf(m))
          if (seen.add(g.id)) g,
    ];
  }

  /// True while any of [keys] has no data yet.
  bool waitingFor(Iterable<String> keys) =>
      keys.any((m) => months[m] == null || (months[m]!.status == MonthStatus.loading && !months[m]!.hasData));

  /// The first failure among [keys] with nothing to show, if any.
  String? failureFor(Iterable<String> keys) {
    for (final m in keys) {
      final mg = months[m];
      if (mg != null && mg.status == MonthStatus.failed && !mg.hasData) return mg.message;
    }
    return null;
  }

  bool fromCacheIn(Iterable<String> keys) => keys.any((m) => months[m]?.fromCache ?? false);

  bool refreshingIn(Iterable<String> keys) => keys.any((m) => months[m]?.refreshing ?? false);

  /// A guest from any loaded month.
  GuestEntity? find(String id) {
    for (final mg in months.values) {
      for (final g in mg.guests) {
        if (g.id == id) return g;
      }
    }
    return null;
  }

  GuestsState put(String month, MonthGuests value) => GuestsState(months: {...months, month: value});

  @override
  List<Object?> get props => [months];
}

/// Filters shared by the Guests screens ('all' | 'call' | 'fu' | 'mem' | 'team').
abstract class GuestFilters {
  static bool matches(GuestEntity g, String filter) => switch (filter) {
        'call' => g.callCount == 0,
        'fu' => g.callCount > 0,
        'mem' => g.status == 'Member',
        'team' => g.teamJoined.isNotEmpty,
        _ => true,
      };

  static List<GuestEntity> apply(List<GuestEntity> guests, String filter) =>
      guests.where((g) => matches(g, filter)).toList();

  static int count(List<GuestEntity> guests, String filter) => guests.where((g) => matches(g, filter)).length;

  /// Name contains [query], or the phone's digits contain the query's digits.
  static List<GuestEntity> search(List<GuestEntity> guests, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return guests;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return guests
        .where((g) =>
            g.name.toLowerCase().contains(q) ||
            (digits.isNotEmpty && g.phone.replaceAll(RegExp(r'\D'), '').contains(digits)))
        .toList();
  }
}
