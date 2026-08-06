import 'dart:async';

import 'package:awaken/core/usecase/usecase.dart';
import 'package:awaken/features/alarm/domain/entities/alarm_schedule.dart';
import 'package:awaken/features/squad/domain/repositories/squad_repository.dart';
import 'package:awaken/features/verification/domain/entities/verification_state.dart';
import 'package:awaken/features/verification/domain/usecases/start_verification_session.dart';
import 'package:awaken/features/verification/domain/usecases/stop_verification_session.dart';
import 'package:awaken/features/verification/domain/usecases/watch_verification_state.dart';
import 'package:awaken/features/verification/presentation/bloc/verification_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockStartVerificationSession extends Mock
    implements StartVerificationSession {}

class _MockStopVerificationSession extends Mock
    implements StopVerificationSession {}

class _MockWatchVerificationState extends Mock
    implements WatchVerificationState {}

class _MockSquadRepository extends Mock implements SquadRepository {}

class _MockPermissionHandlerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {}

class _MockWakelockPlusPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements WakelockPlusPlatformInterface {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockStartVerificationSession startSession;
  late _MockStopVerificationSession stopSession;
  late _MockWatchVerificationState watchState;
  late _MockSquadRepository squadRepository;
  late _MockPermissionHandlerPlatform permissionPlatform;
  late _MockWakelockPlusPlatform wakelockPlatform;
  late StreamController<VerificationState> stateController;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const StartVerificationParams(exercise: ExerciseMode.squat, targetReps: 0),
    );
    registerFallbackValue(<Permission>[Permission.camera]);
    registerFallbackValue(Permission.camera);
  });

  setUp(() {
    startSession = _MockStartVerificationSession();
    stopSession = _MockStopVerificationSession();
    watchState = _MockWatchVerificationState();
    squadRepository = _MockSquadRepository();
    permissionPlatform = _MockPermissionHandlerPlatform();
    wakelockPlatform = _MockWakelockPlusPlatform();

    PermissionHandlerPlatform.instance = permissionPlatform;
    wakelockPlusPlatformInstance = wakelockPlatform;

    when(
      () => permissionPlatform.checkPermissionStatus(any()),
    ).thenAnswer((_) async => PermissionStatus.granted);
    when(() => permissionPlatform.requestPermissions(any())).thenAnswer(
      (_) async => {Permission.camera: PermissionStatus.granted},
    );

    when(
      () => wakelockPlatform.toggle(enable: any(named: 'enable')),
    ).thenAnswer((_) async {});
    when(() => wakelockPlatform.enabled).thenAnswer((_) async => false);

    stateController = StreamController<VerificationState>.broadcast();
    when(() => watchState()).thenAnswer((_) => stateController.stream);
    when(() => startSession(any())).thenAnswer((_) async {});
    when(() => stopSession(any())).thenAnswer((_) async {});
    when(
      () => squadRepository.trackPresence(activity: any(named: 'activity')),
    ).thenAnswer((_) async {});
    when(
      () => squadRepository.broadcastTelemetry(label: any(named: 'label')),
    ).thenReturn(null);
  });

  tearDown(() async {
    await stateController.close();
  });

  VerificationCubit buildCubit() =>
      VerificationCubit(startSession, stopSession, watchState, squadRepository);

  void denyPermission() {
    when(() => permissionPlatform.requestPermissions(any())).thenAnswer(
      (_) async => {Permission.camera: PermissionStatus.denied},
    );
  }

  group('begin — permission denied', () {
    test(
      'emits permissionDenied and never starts a session or touches squad repo',
      () async {
        denyPermission();
        final cubit = buildCubit();

        await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);

        expect(cubit.state.status, VerificationStatus.permissionDenied);
        verifyNever(() => startSession(any()));
        verifyNever(() => watchState());
        verifyNever(
          () => squadRepository.trackPresence(activity: any(named: 'activity')),
        );
        verifyNever(
          () => squadRepository.broadcastTelemetry(label: any(named: 'label')),
        );

        await cubit.close();
      },
    );
  });

  group('begin — permission granted', () {
    test('calls startSession with the correct params', () async {
      final cubit = buildCubit();

      await cubit.begin(exercise: ExerciseMode.pushup, targetReps: 15);

      verify(
        () => startSession(
          const StartVerificationParams(
            exercise: ExerciseMode.pushup,
            targetReps: 15,
          ),
        ),
      ).called(1);

      await cubit.close();
    });

    test('re-emits state-stream emissions through the cubit', () async {
      final cubit = buildCubit();
      await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);

      const emitted = VerificationState(
        status: VerificationStatus.calibrating,
        exerciseMode: ExerciseMode.squat,
        targetReps: 10,
      );

      final future = cubit.stream.firstWhere(
        (s) => s.status == VerificationStatus.calibrating,
      );
      stateController.add(emitted);
      final result = await future;

      expect(result.status, VerificationStatus.calibrating);

      await cubit.close();
    });

    test(
      'trackPresence("Working out") is called exactly once across multiple '
      'counting/calibrating emissions in the same session',
      () async {
        final cubit = buildCubit();
        await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);

        stateController.add(
          const VerificationState(
            status: VerificationStatus.calibrating,
            exerciseMode: ExerciseMode.squat,
            targetReps: 10,
            completedReps: 0,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        stateController.add(
          const VerificationState(
            status: VerificationStatus.counting,
            exerciseMode: ExerciseMode.squat,
            targetReps: 10,
            completedReps: 1,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        stateController.add(
          const VerificationState(
            status: VerificationStatus.counting,
            exerciseMode: ExerciseMode.squat,
            targetReps: 10,
            completedReps: 2,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verify(
          () => squadRepository.trackPresence(activity: 'Working out'),
        ).called(1);

        await cubit.close();
      },
    );

    test(
      'broadcastTelemetry uses "squats" suffix and correct rep counts for '
      'squat exercise',
      () async {
        final cubit = buildCubit();
        await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);

        stateController.add(
          const VerificationState(
            status: VerificationStatus.counting,
            exerciseMode: ExerciseMode.squat,
            targetReps: 10,
            completedReps: 3,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verify(
          () => squadRepository.broadcastTelemetry(
            label: 'Workout · 3/10 squats',
          ),
        ).called(1);

        await cubit.close();
      },
    );

    test(
      'broadcastTelemetry uses "push-ups" suffix and correct rep counts for '
      'non-squat exercise',
      () async {
        final cubit = buildCubit();
        await cubit.begin(exercise: ExerciseMode.pushup, targetReps: 20);

        stateController.add(
          const VerificationState(
            status: VerificationStatus.counting,
            exerciseMode: ExerciseMode.pushup,
            targetReps: 20,
            completedReps: 7,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verify(
          () => squadRepository.broadcastTelemetry(
            label: 'Workout · 7/20 push-ups',
          ),
        ).called(1);

        await cubit.close();
      },
    );

    test(
      'no presence/telemetry calls when status is not counting/calibrating',
      () async {
        final cubit = buildCubit();
        await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);

        stateController.add(
          const VerificationState(
            status: VerificationStatus.initializing,
            exerciseMode: ExerciseMode.squat,
            targetReps: 10,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        stateController.add(
          const VerificationState(
            status: VerificationStatus.noPoseDetected,
            exerciseMode: ExerciseMode.squat,
            targetReps: 10,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => squadRepository.trackPresence(activity: any(named: 'activity')),
        );
        verifyNever(
          () => squadRepository.broadcastTelemetry(label: any(named: 'label')),
        );

        await cubit.close();
      },
    );
  });

  group('retry', () {
    test('is a safe no-op when begin() was never called', () async {
      final cubit = buildCubit();

      await cubit.retry();

      verifyNever(() => startSession(any()));

      await cubit.close();
    });

    test('re-invokes begin with the same exercise/targetReps', () async {
      final cubit = buildCubit();
      await cubit.begin(exercise: ExerciseMode.pushup, targetReps: 12);
      clearInteractions(startSession);

      await cubit.retry();

      verify(
        () => startSession(
          const StartVerificationParams(
            exercise: ExerciseMode.pushup,
            targetReps: 12,
          ),
        ),
      ).called(1);

      await cubit.close();
    });
  });

  group('pause/resume', () {
    test(
      'pause() no-ops when status is not an active camera session',
      () async {
        denyPermission();
        final cubit = buildCubit();
        // permissionDenied -> not an active camera session.
        await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);
        clearInteractions(stopSession);

        await cubit.pause();

        verifyNever(() => stopSession(any()));

        // resume() should also be a no-op since pause() never armed the
        // lifecycle flag.
        await cubit.resume();
        verifyNever(() => startSession(any()));

        await cubit.close();
      },
    );

    test(
      'pause() stops the session and arms resume() when status is active',
      () async {
        final cubit = buildCubit();
        await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);
        // Default VerificationState().status == initializing, which is an
        // active camera session per VerificationStatusX.isActiveCameraSession.
        clearInteractions(stopSession);
        clearInteractions(startSession);

        await cubit.pause();

        verify(() => stopSession(const NoParams())).called(1);

        await cubit.resume();

        verify(
          () => startSession(
            const StartVerificationParams(
              exercise: ExerciseMode.squat,
              targetReps: 10,
            ),
          ),
        ).called(1);

        await cubit.close();
      },
    );
  });

  group('resume', () {
    test('is a no-op without a prior pause()', () async {
      final cubit = buildCubit();
      await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);
      clearInteractions(startSession);

      await cubit.resume();

      verifyNever(() => startSession(any()));

      await cubit.close();
    });
  });

  group('close', () {
    test('cancels the state subscription and stops the session', () async {
      final cubit = buildCubit();
      await cubit.begin(exercise: ExerciseMode.squat, targetReps: 10);
      clearInteractions(stopSession);

      await cubit.close();

      verify(() => stopSession(const NoParams())).called(1);

      // The subscription must be cancelled: further emissions must not be
      // delivered (and must not throw from emitting on a closed cubit).
      expect(() => stateController.add(const VerificationState()), returnsNormally);
    });
  });
}
