import '../core/utils/lagos_time.dart';
import 'entities/guest_entity.dart';

/// What the Today screen shows: the worker's guests who need a call now.
class TodayView {
  /// Not called and more than 3 days since the first visit, longest wait first.
  final List<GuestEntity> outstanding;

  /// Not called, still within the 3 day window, closest to the deadline first.
  final List<GuestEntity> fresh;

  const TodayView({required this.outstanding, required this.fresh});

  int get total => outstanding.length + fresh.length;

  /// The guest to call first.
  GuestEntity? get next => outstanding.isNotEmpty ? outstanding.first : (fresh.isNotEmpty ? fresh.first : null);
}

/// Today's rule, independent of every month filter in the app: guests the
/// worker has not called yet (first visit on or after [since]), split into
/// outstanding (over 3 days, the first call window) and new. Guests already
/// called, members and people who are not interested are left out.
abstract class TodayRules {
  static const firstCallWindowDays = 3;
  static const maxMonths = 6;

  /// Months Today needs: from the month of [since] (at most [maxMonths] back) to this month.
  static List<String> months({required String since, String? today}) {
    final now = (today ?? LagosTime.today()).substring(0, 7);
    final from = since.substring(0, 7);
    final out = <String>[now];
    var y = int.parse(now.substring(0, 4));
    var m = int.parse(now.substring(5, 7));
    while (out.length < maxMonths) {
      m--;
      if (m < 1) {
        m = 12;
        y--;
      }
      final key = '$y-${m.toString().padLeft(2, '0')}';
      if (key.compareTo(from) < 0) break;
      out.add(key);
    }
    return out.reversed.toList();
  }

  static bool needsCall(GuestEntity g, {required String since}) =>
      g.callCount == 0 &&
      g.status != 'Member' &&
      g.status != 'Not interested' &&
      g.serviceDate.isNotEmpty &&
      g.serviceDate.compareTo(since) >= 0;

  static TodayView of(Iterable<GuestEntity> guests, {required String since}) {
    final waiting = guests.where((g) => needsCall(g, since: since)).toList()
      ..sort((a, b) => b.daysSinceVisit.compareTo(a.daysSinceVisit));
    return TodayView(
      outstanding: waiting.where((g) => g.daysSinceVisit > firstCallWindowDays).toList(),
      fresh: waiting.where((g) => g.daysSinceVisit <= firstCallWindowDays).toList(),
    );
  }
}
