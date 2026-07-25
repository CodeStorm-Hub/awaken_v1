import 'package:alarm/alarm.dart';
import 'package:awaken/features/alarm/data/datasources/alarm_local_datasource.dart';
import 'package:awaken/features/alarm/data/datasources/wake_up_tax_store.dart';
import 'package:awaken/features/alarm/data/repositories/alarm_repository_impl.dart';
import 'package:awaken/features/alarm/domain/entities/alarm_schedule.dart';
import 'package:awaken/sync/local/database.dart';
import 'package:awaken/sync/outbox/local_writer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAlarmLocalDataSource extends Mock implements AlarmLocalDataSource {}

class _MockLocalWriter extends Mock implements LocalWriter {}

class _MockWakeUpTaxStore extends Mock implements WakeUpTaxStore {}

class _FakeAlarmSettings extends Fake implements AlarmSettings {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAlarmSettings());
  });

  late _MockAlarmLocalDataSource local;
  late _MockLocalWriter localWriter;
  late AppDatabase db;
  late _MockWakeUpTaxStore taxStore;
  late AlarmRepositoryImpl repository;

  final alarm = AlarmSchedule(
    id: 'real-alarm-id',
    scheduledTime: DateTime(2026, 7, 19, 7),
    exerciseMode: ExerciseMode.squat,
    requiredReps: 20,
  );

  setUp(() {
    local = _MockAlarmLocalDataSource();
    localWriter = _MockLocalWriter();
    db = AppDatabase(NativeDatabase.memory());
    taxStore = _MockWakeUpTaxStore();
    repository = AlarmRepositoryImpl(local, localWriter, db, taxStore);
  });

  tearDown(() => db.close());

  group('AlarmRepositoryImpl.completeWorkout — destructive preview P0 fix', () {
    test('isPreview: true touches no native, local, or tax state at all', () async {
      await repository.completeWorkout(
        alarm,
        verified: true,
        repsCompleted: 20,
        startedAt: DateTime(2026, 7, 19, 6, 59),
        isPreview: true,
      );

      // Must not stop the real alarm's native schedule, must not log a
      // session, and must not mutate the wake-up tax — completing a
      // preview must be entirely side-effect-free.
      verifyNever(() => local.stop(any()));
      verifyNever(
        () => localWriter.insertSession(
          id: any(named: 'id'),
          alarmId: any(named: 'alarmId'),
          exerciseMode: any(named: 'exerciseMode'),
          repsCompleted: any(named: 'repsCompleted'),
          startedAt: any(named: 'startedAt'),
          completedAt: any(named: 'completedAt'),
        ),
      );
      verifyNever(() => taxStore.reset());
      verifyNever(() => taxStore.bump());
    });

    test('isPreview: true does not schedule a recurrence advance either', () async {
      final recurringAlarm = alarm.copyWith(recurringDays: {DateTime.sunday});

      await repository.completeWorkout(
        recurringAlarm,
        verified: false,
        repsCompleted: 3,
        startedAt: DateTime(2026, 7, 19, 6, 59),
        isPreview: true,
      );

      verifyNever(() => local.set(any()));
      verifyNoMoreInteractions(local);
    });

    test('isPreview: false (a real ring) does stop the native alarm and log a session', () async {
      when(() => local.stop(any())).thenAnswer((_) async => true);
      when(
        () => localWriter.insertSession(
          id: any(named: 'id'),
          alarmId: any(named: 'alarmId'),
          exerciseMode: any(named: 'exerciseMode'),
          repsCompleted: any(named: 'repsCompleted'),
          startedAt: any(named: 'startedAt'),
          completedAt: any(named: 'completedAt'),
        ),
      ).thenAnswer((_) async {});
      when(() => taxStore.reset()).thenAnswer((_) async {});
      when(
        () => localWriter.upsertAlarm(
          id: any(named: 'id'),
          nativeId: any(named: 'nativeId'),
          scheduledTime: any(named: 'scheduledTime'),
          exerciseMode: any(named: 'exerciseMode'),
          requiredReps: any(named: 'requiredReps'),
          penaltyMultiplier: any(named: 'penaltyMultiplier'),
          isActive: any(named: 'isActive'),
          recurringDays: any(named: 'recurringDays'),
        ),
      ).thenAnswer((_) async {});

      await repository.completeWorkout(
        alarm,
        verified: true,
        repsCompleted: 20,
        startedAt: DateTime(2026, 7, 19, 6, 59),
      );

      verify(() => local.stop(any())).called(1);
      verify(() => taxStore.reset()).called(1);
      // Non-recurring alarm: the stale-Drift-row fix must mark it inactive
      // so it doesn't keep reporting `isActive: true` after it's done.
      verify(
        () => localWriter.upsertAlarm(
          id: alarm.id,
          nativeId: any(named: 'nativeId'),
          scheduledTime: alarm.scheduledTime,
          exerciseMode: alarm.exerciseMode.name,
          requiredReps: alarm.requiredReps,
          penaltyMultiplier: alarm.penaltyMultiplier,
          isActive: false,
          recurringDays: alarm.recurringDays,
        ),
      ).called(1);
    });
  });
}
