import '../core/constants/work_rules.dart';
import 'entities/guest_entity.dart';
import 'today_rules.dart';

/// One worker with outstanding guests (Today's Outstanding rule).
class WorkerAttention {
  final String workerName;

  /// '' when the guests did not say (older cached data).
  final String workerEmail;
  final int outstanding;

  /// Days the longest-waiting outstanding guest has waited.
  final int oldestDays;

  /// Month ('yyyy-MM') of that guest, to open the worker's list there.
  final String oldestMonth;

  /// The outstanding guests, longest wait first.
  final List<TodayItem> items;

  const WorkerAttention({
    required this.workerName,
    this.workerEmail = '',
    required this.outstanding,
    required this.oldestDays,
    required this.oldestMonth,
    this.items = const [],
  });

  /// The oldest has waited ATTENTION_AFTER_DAYS or more: shown in red.
  bool get urgent => oldestDays >= WorkRules.ATTENTION_AFTER_DAYS;

  /// "David, 4 outstanding, oldest 9 days".
  String get line {
    final first = workerName.trim().split(RegExp(r'\s+')).first;
    return '$first, $outstanding outstanding, oldest $oldestDays ${oldestDays == 1 ? 'day' : 'days'}';
  }
}

/// The HOD's "Needs attention" and the Team screen's red counts: for each
/// worker, their guests since go-live that are Outstanding by Today's rule
/// (never called, more than OUTSTANDING_AFTER_DAYS days since the visit).
abstract class AttentionRules {
  static List<WorkerAttention> build({
    required Iterable<GuestEntity> guests,
    required String since,
    required String today,
  }) {
    // By email when the guests have it, otherwise by name.
    final byWorker = <String, List<GuestEntity>>{};
    for (final g in guests) {
      final name = (g.assignedWorkerName ?? '').trim();
      final key = g.assignedEmail.isNotEmpty ? g.assignedEmail : name.toLowerCase();
      if (key.isEmpty) continue;
      (byWorker[key] ??= []).add(g);
    }
    final out = <WorkerAttention>[];
    byWorker.forEach((key, list) {
      final outstanding = TodayRules.build(guests: list, since: since, today: today).outstanding;
      if (outstanding.isEmpty) return;
      final named = list.map((g) => (g.assignedWorkerName ?? '').trim()).firstWhere((n) => n.isNotEmpty, orElse: () => key);
      out.add(WorkerAttention(
        workerName: named,
        workerEmail: key.contains('@') ? key : '',
        outstanding: outstanding.length,
        oldestDays: outstanding.first.days,
        oldestMonth: outstanding.first.guest.serviceDate.substring(0, 7),
        items: outstanding,
      ));
    });
    out.sort((a, b) => b.oldestDays != a.oldestDays
        ? b.oldestDays - a.oldestDays
        : (b.outstanding != a.outstanding ? b.outstanding - a.outstanding : a.workerName.compareTo(b.workerName)));
    return out;
  }

  /// Every outstanding guest of the team.
  static int total(List<WorkerAttention> list) => list.fold(0, (n, w) => n + w.outstanding);

  /// Outstanding count per worker, keyed by email and by lowercase name (for the Team screen).
  static Map<String, int> counts(List<WorkerAttention> list) => {
        for (final w in list) w.workerName.trim().toLowerCase(): w.outstanding,
        for (final w in list)
          if (w.workerEmail.isNotEmpty) w.workerEmail: w.outstanding,
      };
}
