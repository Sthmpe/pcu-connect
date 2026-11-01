import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/utils/lagos_time.dart';

void main() {
  group('LagosTime.fullDate', () {
    final clock = DateTime.utc(2026, 11, 1, 10);

    test('says the weekday, day and month', () {
      expect(LagosTime.fullDate('2026-10-28', clock: clock), 'Wednesday 28 October');
      expect(LagosTime.fullDate('2026-10-25', clock: clock), 'Sunday 25 October');
    });

    test('adds the year only for another year', () {
      expect(LagosTime.fullDate('2025-12-28', clock: clock), 'Sunday 28 December 2025');
    });

    test('uses the Lagos year at midnight on 31 December', () {
      // 23:30 UTC on 31 Dec is already 1 Jan in Lagos.
      final newYear = DateTime.utc(2026, 12, 31, 23, 30);
      expect(LagosTime.fullDate('2026-12-31', clock: newYear), 'Thursday 31 December 2026');
      expect(LagosTime.fullDate('2027-01-01', clock: newYear), 'Friday 1 January');
    });

    test('is empty for a day it cannot read', () {
      expect(LagosTime.fullDate(''), '');
      expect(LagosTime.fullDate('soon'), '');
    });
  });
}
