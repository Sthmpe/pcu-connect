import '../core/constants/work_rules.dart';
import '../core/utils/lagos_time.dart';
import 'entities/guest_entity.dart';

/// One call the worker can see (followUps where worker == them).
class CallRecord {
  final String guestId;
  final String callDate; // Lagos day 'yyyy-MM-dd'
  final String outcome;
  final String loggedBy;

  /// Server time; null while the save waits to sync (it is then the newest).
  final DateTime? createdAt;

  const CallRecord({
    required this.guestId,
    required this.callDate,
    required this.outcome,
    this.loggedBy = '',
    this.createdAt,
  });
}

/// What the calls say about one guest.
class CallSummary {
  final String lastDay;
  final String lastOutcome;
  final int count;
  const CallSummary({required this.lastDay, required this.lastOutcome, required this.count});
}

enum TodaySection { fresh, outstanding, retry, followUpDue }

/// One guest on Today, with the section that put them there.
class TodayItem {
  final GuestEntity guest;
  final TodaySection section;

  /// Days since the first visit (New, Outstanding) or since the last call (Retry, Follow-up due).
  final int days;

  /// Calls made so far (for "try 2 of 3").
  final int calls;

  const TodayItem({required this.guest, required this.section, required this.days, required this.calls});
}

/// The worker's to-do list for one Lagos day.
class TodayView {
  final List<TodayItem> fresh;
  final List<TodayItem> outstanding;
  final List<TodayItem> retry;
  final List<TodayItem> followUpDue;

  /// Distinct guests this worker logged a call for today.
  final int doneToday;

  const TodayView({
    this.fresh = const [],
    this.outstanding = const [],
    this.retry = const [],
    this.followUpDue = const [],
    this.doneToday = 0,
  });

  /// Guests needing action across all four sections (the Today tab badge).
  int get total => fresh.length + outstanding.length + retry.length + followUpDue.length;

  /// The daily goal ring: done out of done + still due.
  int get ringDone => doneToday;
  int get ringTotal => doneToday + total;

  List<TodayItem> get all => [...fresh, ...outstanding, ...retry, ...followUpDue];

  /// The guest to call first: the longest-waiting outstanding guest, else the next in order.
  TodayItem? get next => outstanding.isNotEmpty ? outstanding.first : (all.isEmpty ? null : all.first);

  TodayItem? itemFor(String guestId) {
    for (final i in all) {
      if (i.guest.id == guestId) return i;
    }
    return null;
  }
}

/// Today's rules (docs: WorkRules). For the signed-in worker's own guests
/// whose first visit is on or after [since] (go-live), independent of every
/// month filter in the app:
/// - New: never called, at most OUTSTANDING_AFTER_DAYS days since the visit.
/// - Outstanding: never called, more than OUTSTANDING_AFTER_DAYS days.
/// - Retry: the last call had no answer (NO_ANSWER_OUTCOMES), at least
///   RETRY_AFTER_DAYS days ago, fewer than MAX_RETRIES calls so far.
/// - Follow-up due: called at least once, status not in NO_FOLLOWUP_STATUSES,
///   no call for FOLLOWUP_DUE_AFTER_DAYS days.
/// A guest is in the first section that applies, and leaves Today once a call
/// is logged and no rule applies.
abstract class TodayRules {
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

  /// Per guest: the latest call day and outcome, and how many calls.
  static Map<String, CallSummary> summarise(Iterable<CallRecord> calls) {
    final byGuest = <String, List<CallRecord>>{};
    for (final c in calls) {
      (byGuest[c.guestId] ??= []).add(c);
    }
    return byGuest.map((id, list) {
      list.sort((a, b) {
        final d = a.callDate.compareTo(b.callDate);
        if (d != 0) return d;
        if (a.createdAt == null || b.createdAt == null) return a.createdAt == null ? 1 : -1;
        return a.createdAt!.compareTo(b.createdAt!);
      });
      return MapEntry(id, CallSummary(lastDay: list.last.callDate, lastOutcome: list.last.outcome, count: list.length));
    });
  }

  /// Distinct guests [worker] logged a call for on [today].
  static int doneToday(Iterable<CallRecord> calls, {required String worker, required String today}) =>
      calls.where((c) => c.callDate == today && c.loggedBy == worker).map((c) => c.guestId).toSet().length;

  /// Builds Today for [guests] (already only the worker's own). [calls] are the
  /// worker's follow-ups when the app can see them (Firestore); otherwise the
  /// guests' own lastCallDate and lastOutcome are used.
  static TodayView build({
    required Iterable<GuestEntity> guests,
    required String since,
    required String today,
    Map<String, CallSummary> calls = const {},
    int doneToday = 0,
  }) {
    final fresh = <TodayItem>[], outstanding = <TodayItem>[], retry = <TodayItem>[], followUpDue = <TodayItem>[];
    for (final g in guests) {
      if (g.serviceDate.isEmpty || g.serviceDate.compareTo(since) < 0) continue;
      final summary = calls[g.id];
      final count = summary == null ? g.callCount : (summary.count > g.callCount ? summary.count : g.callCount);
      final lastDay = summary?.lastDay ?? g.lastCallDate;
      final lastOutcome = summary?.lastOutcome ?? g.lastOutcome;

      if (count == 0 && lastDay.isEmpty) {
        final age = LagosTime.daysBetween(g.serviceDate, today);
        final item = TodayItem(guest: g, section: TodaySection.fresh, days: age < 0 ? 0 : age, calls: 0);
        if (age <= WorkRules.OUTSTANDING_AFTER_DAYS) {
          fresh.add(item);
        } else {
          outstanding.add(TodayItem(guest: g, section: TodaySection.outstanding, days: age, calls: 0));
        }
        continue;
      }

      // Called. Without a known call day, the first visit is the safe stand-in.
      final since0 = LagosTime.daysBetween(lastDay.isEmpty ? g.serviceDate : lastDay, today);
      if (WorkRules.NO_ANSWER_OUTCOMES.contains(lastOutcome) &&
          since0 >= WorkRules.RETRY_AFTER_DAYS &&
          count < WorkRules.MAX_RETRIES) {
        retry.add(TodayItem(guest: g, section: TodaySection.retry, days: since0, calls: count));
      } else if (!WorkRules.NO_FOLLOWUP_STATUSES.contains(g.status) && since0 >= WorkRules.FOLLOWUP_DUE_AFTER_DAYS) {
        followUpDue.add(TodayItem(guest: g, section: TodaySection.followUpDue, days: since0, calls: count));
      }
    }
    int longestFirst(TodayItem a, TodayItem b) => b.days.compareTo(a.days);
    return TodayView(
      fresh: fresh..sort(longestFirst),
      outstanding: outstanding..sort(longestFirst),
      retry: retry..sort(longestFirst),
      followUpDue: followUpDue..sort(longestFirst),
      doneToday: doneToday,
    );
  }
}
