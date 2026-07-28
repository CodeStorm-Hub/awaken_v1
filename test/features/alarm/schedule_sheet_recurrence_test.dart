import 'package:awaken/features/alarm/domain/entities/alarm_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmSchedule.firstOccurrence', () {
    test('one-shot: time still ahead today -> returns today at that time', () {
      // 2026-07-20 is a Monday.
      final result = AlarmSchedule.firstOccurrence(
        timeOfDay: DateTime(2026, 7, 20, 9),
        recurringDays: const {},
        from: DateTime(2026, 7, 20, 7),
      );
      expect(result, DateTime(2026, 7, 20, 9));
    });

    test('one-shot: time already passed today -> rolls to tomorrow', () {
      final result = AlarmSchedule.firstOccurrence(
        timeOfDay: DateTime(2026, 7, 20, 6),
        recurringDays: const {},
        from: DateTime(2026, 7, 20, 7),
      );
      expect(result, DateTime(2026, 7, 21, 6));
    });

    test(
      'recurring: created on a weekday not in the selection -> lands on the '
      'selected day, not tomorrow',
      () {
        // 2026-07-20 is a Monday. Only Saturday selected — previously this
        // ignored recurringDays entirely and scheduled for Tuesday.
        final result = AlarmSchedule.firstOccurrence(
          timeOfDay: DateTime(2026, 7, 20, 7),
          recurringDays: {DateTime.saturday},
          from: DateTime(2026, 7, 20, 8),
        );
        expect(result, DateTime(2026, 7, 25, 7));
        expect(result.weekday, DateTime.saturday);
      },
    );

    test(
      'recurring: today is a selected day and still ahead -> fires today',
      () {
        // 2026-07-20 is a Monday, selected, slot still ahead.
        final result = AlarmSchedule.firstOccurrence(
          timeOfDay: DateTime(2026, 7, 20, 20),
          recurringDays: {DateTime.monday},
          from: DateTime(2026, 7, 20, 8),
        );
        expect(result, DateTime(2026, 7, 20, 20));
      },
    );

    test(
      'recurring: today is selected but slot already passed -> rolls to '
      'next selected day, not today again',
      () {
        final result = AlarmSchedule.firstOccurrence(
          timeOfDay: DateTime(2026, 7, 20, 6),
          recurringDays: {DateTime.monday},
          from: DateTime(2026, 7, 20, 8),
        );
        expect(result, DateTime(2026, 7, 27, 6));
      },
    );
  });
}
