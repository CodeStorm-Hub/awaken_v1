import 'dart:async';

import 'package:awaken/features/alarm/domain/entities/alarm_schedule.dart';
import 'package:awaken/features/alarm/domain/usecases/cancel_alarm.dart';
import 'package:awaken/features/alarm/domain/usecases/complete_alarm_workout.dart';
import 'package:awaken/features/alarm/domain/usecases/dismiss_alarm.dart';
import 'package:awaken/features/alarm/domain/usecases/schedule_alarm.dart';
import 'package:awaken/features/alarm/domain/usecases/set_alarm_active.dart';
import 'package:awaken/features/alarm/domain/usecases/watch_alarms.dart';
import 'package:awaken/features/alarm/domain/usecases/watch_current_tax_multiplier.dart';
import 'package:awaken/features/alarm/domain/usecases/watch_ringing_alarm.dart';
import 'package:awaken/features/alarm/presentation/bloc/alarm_cubit.dart';
import 'package:awaken/features/alarm/presentation/bloc/alarm_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchAlarms extends Mock implements WatchAlarms {}

class _MockWatchRingingAlarm extends Mock implements WatchRingingAlarm {}

class _MockScheduleAlarm extends Mock implements ScheduleAlarm {}

class _MockCancelAlarm extends Mock implements CancelAlarm {}

class _MockDismissAlarm extends Mock implements DismissAlarm {}

class _MockCompleteAlarmWorkout extends Mock implements CompleteAlarmWorkout {}

class _MockWatchCurrentTaxMultiplier extends Mock
    implements WatchCurrentTaxMultiplier {}

class _MockSetAlarmActive extends Mock implements SetAlarmActive {}

void main() {
  late _MockWatchAlarms watchAlarms;
  late _MockWatchRingingAlarm watchRingingAlarm;
  late _MockScheduleAlarm scheduleAlarm;
  late _MockCancelAlarm cancelAlarm;
  late _MockDismissAlarm dismissAlarm;
  late _MockCompleteAlarmWorkout completeAlarmWorkout;
  late _MockWatchCurrentTaxMultiplier watchCurrentTaxMultiplier;
  late _MockSetAlarmActive setAlarmActive;

  final alarm = AlarmSchedule(
    id: 'alarm-1',
    scheduledTime: DateTime(2026, 8, 7, 7),
    exerciseMode: ExerciseMode.squat,
    requiredReps: 20,
  );

  setUpAll(() {
    registerFallbackValue(alarm);
    registerFallbackValue(
      CompleteAlarmWorkoutParams(
        alarm: alarm,
        verified: true,
        repsCompleted: 20,
        startedAt: DateTime(2026, 8, 7, 6, 59),
      ),
    );
    registerFallbackValue(const SetAlarmActiveParams(id: '', isActive: true));
  });

  setUp(() {
    watchAlarms = _MockWatchAlarms();
    watchRingingAlarm = _MockWatchRingingAlarm();
    scheduleAlarm = _MockScheduleAlarm();
    cancelAlarm = _MockCancelAlarm();
    dismissAlarm = _MockDismissAlarm();
    completeAlarmWorkout = _MockCompleteAlarmWorkout();
    watchCurrentTaxMultiplier = _MockWatchCurrentTaxMultiplier();
    setAlarmActive = _MockSetAlarmActive();

    // Defaults: never-ending empty streams so the constructor's subscribe
    // calls don't crash. Individual tests override with real emissions.
    when(() => watchAlarms()).thenAnswer((_) => const Stream.empty());
    when(() => watchRingingAlarm()).thenAnswer((_) => const Stream.empty());
    when(
      () => watchCurrentTaxMultiplier(),
    ).thenAnswer((_) => const Stream.empty());
  });

  AlarmCubit buildCubit() => AlarmCubit(
    watchAlarms,
    watchRingingAlarm,
    scheduleAlarm,
    cancelAlarm,
    dismissAlarm,
    completeAlarmWorkout,
    watchCurrentTaxMultiplier,
    setAlarmActive,
  );

  test('initial state is const AlarmState()', () {
    final cubit = buildCubit();
    expect(cubit.state, const AlarmState());
    cubit.close();
  });

  group('watchAlarms', () {
    blocTest<AlarmCubit, AlarmState>(
      'updates state.alarms on emission',
      setUp: () => when(
        () => watchAlarms(),
      ).thenAnswer((_) => Stream.value([alarm])),
      build: buildCubit,
      expect: () => [
        isA<AlarmState>().having((s) => s.alarms, 'alarms', [alarm]),
      ],
    );
  });

  group('watchRingingAlarm', () {
    blocTest<AlarmCubit, AlarmState>(
      'updates state.ringingAlarm on emission',
      setUp: () => when(
        () => watchRingingAlarm(),
      ).thenAnswer((_) => Stream.value(alarm)),
      build: buildCubit,
      expect: () => [
        isA<AlarmState>().having(
          (s) => s.ringingAlarm,
          'ringingAlarm',
          alarm,
        ),
      ],
    );

    blocTest<AlarmCubit, AlarmState>(
      'transitions ringing -> dismissed (null), exercising the copyWith '
      'unset-sentinel so a dismissed alarm actually clears ringingAlarm',
      setUp: () => when(
        () => watchRingingAlarm(),
      ).thenAnswer((_) => Stream.fromIterable([alarm, null])),
      build: buildCubit,
      expect: () => [
        isA<AlarmState>().having(
          (s) => s.ringingAlarm,
          'ringingAlarm',
          alarm,
        ),
        isA<AlarmState>().having((s) => s.ringingAlarm, 'ringingAlarm', null),
      ],
    );
  });

  group('watchCurrentTaxMultiplier', () {
    blocTest<AlarmCubit, AlarmState>(
      'updates state.currentTaxMultiplier on emission',
      setUp: () => when(
        () => watchCurrentTaxMultiplier(),
      ).thenAnswer((_) => Stream.value(1.5)),
      build: buildCubit,
      expect: () => [
        isA<AlarmState>().having(
          (s) => s.currentTaxMultiplier,
          'currentTaxMultiplier',
          1.5,
        ),
      ],
    );
  });

  group('delegating methods', () {
    test('schedule() calls through to ScheduleAlarm with the alarm', () async {
      when(() => scheduleAlarm(any())).thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.schedule(alarm);

      verify(() => scheduleAlarm(alarm)).called(1);
      await cubit.close();
    });

    test('cancel() calls through to CancelAlarm with the id', () async {
      when(() => cancelAlarm(any())).thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.cancel('alarm-1');

      verify(() => cancelAlarm('alarm-1')).called(1);
      await cubit.close();
    });

    test('dismiss() calls through to DismissAlarm with the id', () async {
      when(() => dismissAlarm(any())).thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.dismiss('alarm-1');

      verify(() => dismissAlarm('alarm-1')).called(1);
      await cubit.close();
    });

    test(
      'setActive() calls through to SetAlarmActive with id + isActive',
      () async {
        when(() => setAlarmActive(any())).thenAnswer((_) async {});
        final cubit = buildCubit();

        await cubit.setActive('alarm-1', false);

        verify(
          () => setAlarmActive(
            const SetAlarmActiveParams(id: 'alarm-1', isActive: false),
          ),
        ).called(1);
        await cubit.close();
      },
    );

    test(
      'completeWorkout() calls through to CompleteAlarmWorkout with the '
      'right params',
      () async {
        when(() => completeAlarmWorkout(any())).thenAnswer((_) async {});
        final cubit = buildCubit();
        final startedAt = DateTime(2026, 8, 7, 6, 59);

        await cubit.completeWorkout(
          alarm,
          verified: true,
          repsCompleted: 20,
          startedAt: startedAt,
          isPreview: true,
        );

        verify(
          () => completeAlarmWorkout(
            CompleteAlarmWorkoutParams(
              alarm: alarm,
              verified: true,
              repsCompleted: 20,
              startedAt: startedAt,
              isPreview: true,
            ),
          ),
        ).called(1);
        await cubit.close();
      },
    );
  });

  group('setVerificationInProgress', () {
    // Real production bug (see AlarmState.verificationInProgress doc
    // comment): the ring overlay always repainted on top of the pushed
    // VerificationPage, making the camera-verification UI permanently
    // invisible and un-interactable — a deadlock, since the alarm could
    // then never be dismissed. This flag is the fix, so it's worth pinning
    // down explicitly rather than relying on it being exercised indirectly.
    blocTest<AlarmCubit, AlarmState>(
      'toggles verificationInProgress true then false',
      build: buildCubit,
      act: (cubit) {
        cubit.setVerificationInProgress(true);
        cubit.setVerificationInProgress(false);
      },
      expect: () => [
        isA<AlarmState>().having(
          (s) => s.verificationInProgress,
          'verificationInProgress',
          true,
        ),
        isA<AlarmState>().having(
          (s) => s.verificationInProgress,
          'verificationInProgress',
          false,
        ),
      ],
    );
  });

  group('close', () {
    test(
      'cancels all three stream subscriptions cleanly with no further '
      'emissions afterward',
      () async {
        final alarmsController = StreamController<List<AlarmSchedule>>();
        final ringingController = StreamController<AlarmSchedule?>();
        final taxController = StreamController<double>();

        when(
          () => watchAlarms(),
        ).thenAnswer((_) => alarmsController.stream);
        when(
          () => watchRingingAlarm(),
        ).thenAnswer((_) => ringingController.stream);
        when(
          () => watchCurrentTaxMultiplier(),
        ).thenAnswer((_) => taxController.stream);

        final cubit = buildCubit();

        await expectLater(cubit.close(), completes);

        // Emitting after close must not throw and must not reach the
        // (now-closed) cubit.
        expect(alarmsController.isClosed, isFalse);
        alarmsController.add([alarm]);
        ringingController.add(alarm);
        taxController.add(2);
        expect(cubit.state, const AlarmState());

        await alarmsController.close();
        await ringingController.close();
        await taxController.close();
      },
    );
  });
}
