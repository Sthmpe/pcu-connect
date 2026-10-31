import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/utils/month_utils.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/entities/insights.dart';
import 'package:workflow/domain/entities/team_member.dart';

void main() {
  test('guest history parses the admin "Logged by" flag', () {
    final g = GuestEntity.fromJson({
      'id': 'G1',
      'name': 'Ada Obi',
      'month': '2026-10',
      'assignedName': 'David Olanite',
      'history': [
        {
          'id': 'f2',
          'date': '2026-10-30',
          'outcome': 'Reached',
          'workerName': 'David Olanite',
          'loggedByName': 'Opeyemi Olanite',
          'loggedByAdmin': true,
        },
        {'id': 'f1', 'date': '2026-10-28', 'outcome': 'No answer', 'workerName': 'David Olanite'},
      ],
    });
    expect(g.history, hasLength(2));
    expect(g.history.first.loggedByAdmin, isTrue);
    expect(g.history.first.workerName, 'David Olanite');
    expect(g.history.last.loggedByAdmin, isFalse);
  });

  test('guest without history parses to an empty list', () {
    expect(GuestEntity.fromJson({'id': 'G2'}).history, isEmpty);
  });

  test('team member and ranking parse the API shapes', () {
    final m = TeamMember.fromJson({
      'id': 'W005',
      'name': 'David Olanite',
      'email': 'david@x.com',
      'role': 'Worker',
      'active': true,
      'guests': 6,
      'contacted': 5,
      'points': 125,
    });
    expect(m.active, isTrue);
    expect(m.standing, 'On track');
    expect(m.points, 125);

    final r = Ranking.fromJson({
      'month': '2026-10',
      'entries': [
        {'email': 'david@x.com', 'name': 'David', 'points': 125, 'rank': 1},
      ],
      'me': {'email': 'david@x.com', 'name': 'David', 'points': 125, 'rank': 1},
    });
    expect(r.entries.single.rank, 1);
    expect(r.me?.email, 'david@x.com');
  });

  test('dashboard summary works out who is still waiting', () {
    final d = DashboardSummary.fromJson({
      'month': '2026-10',
      'totals': {'guests': 34, 'called': 27, 'members': 5, 'inTeam': 7, 'followUps': 60},
      'topWorkers': [],
    });
    expect(d.notCalled, 7);
    expect(d.calledRate, closeTo(0.794, 0.001));
  });

  test('month keys match the API format and format for display', () {
    expect(MonthUtils.keyOf(DateTime(2026, 10, 31)), '2026-10');
    expect(MonthUtils.label('2026-10'), 'October 2026');
    expect(MonthUtils.recent(3), hasLength(3));
    expect(MonthUtils.recent(3).first, MonthUtils.current());
  });
}
