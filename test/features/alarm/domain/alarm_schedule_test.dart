import 'package:awaken/features/alarm/domain/entities/alarm_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmSchedule.nextOccurrenceAfter', () {
    test('one-shot alarm (empty recurringDays) returns null', () {
      final alarm = AlarmSchedule(
        id: 'a',
        scheduledTime: DateTime(2026, 7, 19, 7),
        exerciseMode: ExerciseMode.squat,
        requiredReps: 20,
      );
      expect(alarm.nextOccurrenceAfter(DateTime(2026, 7, 19, 8)), isNull);
    });

    test('single weekday: rolls to the same weekday next week when today matches', () {
      // 2026-07-19 is a Sunday (DateTime.sunday == 7).
      final alarm = AlarmSchedule(
        id: 'a',
        scheduledTime: DateTime(2026, 7, 19, 7),
        exerciseMode: ExerciseMode.squat,
        requiredReps: 20,
        recurringDays: {DateTime.sunday},
      );
      final next = alarm.nextOccurrenceAfter(DateTime(2026, 7, 19, 8));
      expect(next, DateTime(2026, 7, 26, 7));
    });

    test('multiple weekdays: picks the nearest upcoming one, preserving time-of-day', () {
      // 2026-07-19 is a Sunday. Mon/Wed/Fri selected -> next is Monday 2026-07-20.
      final alarm = AlarmSchedule(
        id: 'a',
        scheduledTime: DateTime(2026, 7, 19, 6, 30),
        exerciseMode: ExerciseMode.pushup,
        requiredReps: 15,
        recurringDays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
      );
      final next = alarm.nextOccurrenceAfter(DateTime(2026, 7, 19, 9));
      expect(next, DateTime(2026, 7, 20, 6, 30));
    });

    test('is always strictly after "from", even same weekday same day', () {
      final alarm = AlarmSchedule(
        id: 'a',
        scheduledTime: DateTime(2026, 7, 19, 7),
        exerciseMode: ExerciseMode.squat,
        requiredReps: 20,
        recurringDays: {DateTime.sunday},
      );
      // "from" is later the same Sunday — must not return today's date again.
      final next = alarm.nextOccurrenceAfter(DateTime(2026, 7, 19, 23));
      expect(next!.isAfter(DateTime(2026, 7, 19, 23)), isTrue);
      expect(next.weekday, DateTime.sunday);
    });

    test('same-day repair: returns today when today is a recurring day and '
        "today's slot is still ahead of \"from\"", () {
      // 2026-07-19 is a Sunday. Alarm fires at 07:00; app relaunches at
      // 06:00 the same day (e.g. crash recovery before the slot fired) —
      // must pick today 07:00, not skip a week ahead.
      final alarm = AlarmSchedule(
        id: 'a',
        scheduledTime: DateTime(2026, 7, 19, 7),
        exerciseMode: ExerciseMode.squat,
        requiredReps: 20,
        recurringDays: {DateTime.sunday},
      );
      final next = alarm.nextOccurrenceAfter(DateTime(2026, 7, 19, 6));
      expect(next, DateTime(2026, 7, 19, 7));
    });

    test('isRecurring reflects recurringDays', () {
      final oneShot = AlarmSchedule(
        id: 'a',
        scheduledTime: DateTime(2026, 7, 19),
        exerciseMode: ExerciseMode.squat,
        requiredReps: 20,
      );
      final recurring = oneShot.copyWith(recurringDays: {DateTime.monday});
      expect(oneShot.isRecurring, isFalse);
      expect(recurring.isRecurring, isTrue);
    });
  });
}
