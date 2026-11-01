import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/utils/lagos_time.dart';
import 'package:workflow/data/firestore/firestore_mappers.dart';
import 'package:workflow/domain/follow_up_rules.dart';

GuestWorkState guest({
  String serviceDate = '2026-10-28', // a Wednesday
  String status = 'New guest',
  int count = 0,
  bool hasFollowUps = false,
  String team = '',
  List<String> sundays = const [],
  List<String> wednesdays = const [],
}) =>
    GuestWorkState(
      serviceDate: serviceDate,
      status: status,
      followUpCount: count,
      hasFollowUps: hasFollowUps,
      teamJoined: team,
      sundayDates: sundays,
      wednesdayDates: wednesdays,
      hasMemberSince: false,
    );

const today = '2026-11-01';

void main() {
  group('points', () {
    test('first call within 3 days earns 10, later 5', () {
      final onTime = FollowUpRules.apply(guest(serviceDate: '2026-10-29'), const FollowUpInput(outcome: 'Reached', note: ''), today: today);
      expect(onTime.points, 10);
      expect(onTime.isFirstCall, isTrue);
      final late = FollowUpRules.apply(guest(serviceDate: '2026-10-28'), const FollowUpInput(outcome: 'No answer', note: ''), today: today);
      expect(late.points, 5);
      final again = FollowUpRules.apply(guest(hasFollowUps: true, count: 1), const FollowUpInput(outcome: 'Reached', note: ''), today: today);
      expect(again.points, 5);
      expect(again.isFirstCall, isFalse);
    });

    test('attendance +10 each, team join +20 only the first time', () {
      final r = FollowUpRules.apply(
        guest(hasFollowUps: true, count: 1),
        const FollowUpInput(outcome: 'Reached', note: '', attendedSunday: true, sundayDate: '2026-11-01',
            attendedWednesday: true, wednesdayDate: '2026-10-28', team: 'Workforce'),
        today: today,
      );
      expect(r.points, 5 + 10 + 10 + 20);
      expect(r.teamJoined, 'Workforce');
      final second = FollowUpRules.apply(guest(hasFollowUps: true, count: 2, team: 'Workforce'),
          const FollowUpInput(outcome: 'Reached', note: '', team: 'Evangelism'), today: today);
      expect(second.points, 5);
      expect(second.teamJoined, 'Evangelism');
    });
  });

  group('member rule (same calendar month)', () {
    test('first visit on a Wednesday + 3 Sundays is not yet a member; the 4th Sunday is', () {
      var g = guest(hasFollowUps: true, count: 1, status: 'Contacted');
      FollowUpResult r;
      for (final day in ['2026-10-04', '2026-10-11', '2026-10-18']) {
        r = FollowUpRules.apply(g, FollowUpInput(outcome: 'Reached', note: '', attendedSunday: true, sundayDate: day), today: today);
        expect(r.status, isNot('Member'));
        g = guest(hasFollowUps: true, count: r.followUpCount, status: r.status, sundays: r.sundayDates, wednesdays: r.wednesdayDates);
      }
      r = FollowUpRules.apply(g, const FollowUpInput(outcome: 'Reached', note: '', attendedSunday: true, sundayDate: '2026-10-25'), today: today);
      expect(r.status, 'Member');
      expect(r.becameMember, isTrue);
      expect(r.points, 5 + 10 + 30);
    });

    test('3 Sundays and 2 Wednesdays make a member', () {
      final g = guest(hasFollowUps: true, count: 3, status: 'Returning',
          sundays: ['2026-10-04', '2026-10-11', '2026-10-18'], wednesdays: ['2026-10-28']);
      final r = FollowUpRules.apply(g,
          const FollowUpInput(outcome: 'Reached', note: '', attendedWednesday: true, wednesdayDate: '2026-10-21'), today: today);
      expect(r.status, 'Member');
      expect(r.points, 45);
    });

    test('attendance across two months does not add up', () {
      expect(FollowUpRules.qualifies(['2026-09-27', '2026-10-04', '2026-10-11', '2026-10-18'], const []), isFalse);
      expect(FollowUpRules.qualifies(['2026-10-04', '2026-10-04', '2026-10-11', '2026-10-18'], const []), isFalse);
    });

    test('a member stays a member and earns no member points again', () {
      final r = FollowUpRules.apply(guest(hasFollowUps: true, count: 5, status: 'Member'),
          const FollowUpInput(outcome: 'Not interested', note: ''), today: today);
      expect(r.status, 'Member');
      expect(r.points, 5);
    });
  });

  group('status order', () {
    FollowUpResult after(String status, String outcome, {int count = 1, bool attended = false}) =>
        FollowUpRules.apply(guest(hasFollowUps: true, count: count, status: status),
            FollowUpInput(outcome: outcome, note: '', attendedSunday: attended, sundayDate: attended ? '2026-11-01' : ''),
            today: today);

    test('not interested is sticky over returning and contacted', () {
      expect(after('Not interested', 'Reached', attended: true).status, 'Not interested');
      expect(after('Returning', 'Not interested').status, 'Not interested');
    });
    test('attendance makes returning, reached makes contacted', () {
      expect(after('Contacted', 'No answer', attended: true).status, 'Returning');
      expect(after('New guest', 'Reached').status, 'Contacted');
      expect(after('Returning', 'No answer').status, 'Returning');
    });
    test('unreachable after 3 calls without reaching them', () {
      expect(after('New guest', 'No answer', count: 1).status, 'New guest');
      expect(after('New guest', 'Busy', count: 2).status, 'Unreachable');
      expect(after('Unreachable', 'Reached', count: 3).status, 'Contacted');
    });
  });

  group('validation', () {
    test('future attendance, unknown outcome or team, and missing date are refused', () {
      expect(FollowUpRules.validate(const FollowUpInput(outcome: 'Reached', note: '', attendedSunday: true, sundayDate: '2026-11-02'), today: today),
          'Attendance date cannot be in the future.');
      expect(FollowUpRules.validate(const FollowUpInput(outcome: 'Number off', note: ''), today: today), isNotNull);
      expect(FollowUpRules.validate(const FollowUpInput(outcome: 'Reached', note: '', team: 'Choir'), today: today), isNotNull);
      expect(FollowUpRules.validate(const FollowUpInput(outcome: 'Reached', note: '', attendedWednesday: true), today: today),
          'Pick the date they attended.');
      expect(FollowUpRules.validate(const FollowUpInput(outcome: 'Reached', note: 'ok', attendedSunday: true, sundayDate: today), today: today), isNull);
    });
  });

  group('Lagos days and the Firestore guest document', () {
    test('Wednesday check and picked dates', () {
      expect(LagosTime.isWednesday('2026-10-28'), isTrue);
      expect(LagosTime.isWednesday('2026-11-01'), isFalse);
      expect(LagosTime.pickedDay(DateTime(2026, 10, 4)), '2026-10-04');
    });
    test('work state from a guest document; the first visit counts once', () {
      final s = FirestoreMappers.workState({
        'serviceDate': '2026-10-28',
        'membershipStatus': 'Contacted',
        'followUpCount': 2,
        'firstCallAt': DateTime(2026, 10, 29),
        'sundayDates': ['2026-10-04'],
        'wednesdayDates': ['2026-10-28'],
      });
      expect(s.hasFollowUps, isTrue);
      expect(s.followUpCount, 2);
      final r = FollowUpRules.apply(s, const FollowUpInput(outcome: 'Reached', note: ''), today: today);
      expect(r.wednesdayDates, ['2026-10-28']);
      expect(r.followUpCount, 3);
      final fresh = FirestoreMappers.workState({'serviceDate': '2026-10-28'});
      expect(fresh.hasFollowUps, isFalse);
      expect(fresh.status, '');
      expect(FollowUpRules.apply(fresh, const FollowUpInput(outcome: 'No answer', note: ''), today: today).status, 'New guest');
    });
  });
}
