import '../core/constants/work_rules.dart';
import 'entities/guest_entity.dart';
import 'today_rules.dart';

/// One worker with outstanding guests (Today's Outstanding rule).
class WorkerAttention {
  final String workerName;
  final int outstanding;

  /// Days the longest-waiting outstanding guest has waited.
  final int oldestDays;

  /// Month ('yyyy-MM') of that guest, to open the worker's list there.
  final String oldestMonth;

  const WorkerAttention({
    required this.workerName,
    required this.outstanding,
    required this.oldestDays,
    required this.oldestMonth,
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
    final byWorker = <String, List<GuestEntity>>{};
    for (final g in guests) {
      final name = (g.assignedWorkerName ?? '').trim();
      if (name.isEmpty) continue;
      (byWorker[name] ??= []).add(g);
    }
    final out = <WorkerAttention>[];
    byWorker.forEach((name, list) {
      final outstanding = TodayRules.build(guests: list, since: since, today: today).outstanding;
      if (outstanding.isEmpty) return;
      out.add(WorkerAttention(
        workerName: name,
        outstanding: outstanding.length,
        oldestDays: outstanding.first.days,
        oldestMonth: outstanding.first.guest.serviceDate.substring(0, 7),
      ));
    });
    out.sort((a, b) => b.oldestDays != a.oldestDays
        ? b.oldestDays - a.oldestDays
        : (b.outstanding != a.outstanding ? b.outstanding - a.outstanding : a.workerName.compareTo(b.workerName)));
    return out;
  }

  /// Outstanding count per worker name (for the Team screen).
  static Map<String, int> counts(List<WorkerAttention> list) =>
      {for (final w in list) w.workerName.trim().toLowerCase(): w.outstanding};
}
