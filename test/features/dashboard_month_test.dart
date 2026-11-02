import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/domain/attention_rules.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/entities/insights.dart';
import 'package:workflow/domain/insight_rules.dart';
import 'package:workflow/presentation/guests/bloc/guests_filter_cubit.dart';

GuestEntity g(String id, String visit, String worker) => GuestEntity(
      id: id, name: id, phone: '', status: 'New guest', daysSinceVisit: 0, serviceDate: visit, callCount: 0,
      sundayAttendance: 0, wednesdayAttendance: 0, teamJoined: '', lastFeedback: '', lastFeedbackDate: '',
      followUpCount: 0, month: visit.substring(0, 7), assignedWorkerName: worker, assignedEmail: '${worker.toLowerCase()}@x.com',
    );

void main() {
  test('Needs attention for a month: only outstanding guests who first visited that month', () {
    final guests = [g('o1', '2026-10-28', 'David'), g('o2', '2026-10-29', 'Ada'), g('n1', '2026-11-01', 'David')];
    final oct = AttentionRules.build(guests: guests.where((x) => x.month == '2026-10'), since: '2026-10-28', today: '2026-11-08');
    final nov = AttentionRules.build(guests: guests.where((x) => x.month == '2026-11'), since: '2026-10-28', today: '2026-11-08');
    expect(oct.map((w) => '${w.workerName} ${w.outstanding}'), ['David 1', 'Ada 1']);
    expect(nov.map((w) => '${w.workerName} ${w.outstanding}'), ['David 1']);
  });

  test("Top workers: every worker's record for the month, with points, calls and members", () {
    const users = [
      InsightUser(email: 'd@x.com', name: 'David', isAdmin: false, active: true),
      InsightUser(email: 'a@x.com', name: 'Ada', isAdmin: false, active: true),
      InsightUser(email: 'b@x.com', name: 'Bola', isAdmin: false, active: true),
      InsightUser(email: 'w@x.com', name: 'Wale', isAdmin: false, active: true),
      InsightUser(email: 'boss@x.com', name: 'Boss', isAdmin: true, active: true),
    ];
    final guests = [
      for (final (id, to) in [('G1', 'd@x.com'), ('G2', 'a@x.com'), ('G3', 'b@x.com'), ('G4', 'w@x.com')])
        InsightGuest(id: id, serviceDate: '2026-10-28', month: '2026-10', assignedTo: to, status: 'Contacted'),
    ];
    final fus = [
      const InsightFollowUp(guestId: 'G1', worker: 'd@x.com', callDate: '2026-10-29'),
      const InsightFollowUp(guestId: 'G1', worker: 'd@x.com', callDate: '2026-10-30'),
      const InsightFollowUp(guestId: 'G2', worker: 'a@x.com', callDate: '2026-10-29'),
      const InsightFollowUp(guestId: 'G3', worker: 'b@x.com', callDate: '2026-11-02'),
      const InsightFollowUp(guestId: 'G4', worker: 'w@x.com', callDate: '2026-10-31'),
    ];
    final oct = InsightRules.dashboard('2026-10', guests, fus, users);
    expect(oct.topWorkers.length, 3, reason: 'every worker with a record, not only a top three; Bola called in November');
    final david = oct.topWorkers.firstWhere((w) => w.email == 'd@x.com');
    expect([david.points, david.calls, david.members], [15, 2, 0]);
    expect(david.record, '15 pts · 2 calls · 0 members');
    final nov = InsightRules.dashboard('2026-11', guests, fus, users);
    expect(nov.topWorkers.map((w) => w.email), ['b@x.com']);
    expect(const TopWorker(email: 'x', name: 'x', members: 1, points: 30).record, '30 pts · 1 member',
        reason: 'calls only where the source says');
  });

  test("the Guests month never follows the Dashboard's", () {
    final guestsFilter = GuestsFilterCubit(month: '2026-11');
    // The Dashboard moving to October is DashboardCubit.load('2026-10'): it never touches this cubit.
    expect(guestsFilter.state.month, '2026-11');
  });
}
