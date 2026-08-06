import 'dart:async';

import 'package:awaken/core/usecase/usecase.dart';
import 'package:awaken/features/squad/domain/repositories/squad_repository.dart';
import 'package:awaken/features/territory/domain/entities/run_capture_result.dart';
import 'package:awaken/features/territory/domain/entities/run_track_state.dart';
import 'package:awaken/features/territory/domain/usecases/abandon_run.dart';
import 'package:awaken/features/territory/domain/usecases/capture_run.dart';
import 'package:awaken/features/territory/domain/usecases/start_run.dart';
import 'package:awaken/features/territory/domain/usecases/watch_run_state.dart';
import 'package:awaken/features/territory/presentation/bloc/run_tracking_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStartRun extends Mock implements StartRun {}

class _MockAbandonRun extends Mock implements AbandonRun {}

class _MockCaptureRun extends Mock implements CaptureRun {}

class _MockWatchRunState extends Mock implements WatchRunState {}

class _MockSquadRepository extends Mock implements SquadRepository {}

void main() {
  late _MockStartRun startRun;
  late _MockAbandonRun abandonRun;
  late _MockCaptureRun captureRun;
  late _MockWatchRunState watchRunState;
  late _MockSquadRepository squadRepository;
  late StreamController<RunTrackState> controller;

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    startRun = _MockStartRun();
    abandonRun = _MockAbandonRun();
    captureRun = _MockCaptureRun();
    watchRunState = _MockWatchRunState();
    squadRepository = _MockSquadRepository();
    controller = StreamController<RunTrackState>.broadcast();

    when(() => watchRunState()).thenAnswer((_) => controller.stream);
    when(() => startRun(any())).thenAnswer((_) async {});
    when(() => abandonRun(any())).thenAnswer((_) async {});
    when(
      () => captureRun(any()),
    ).thenAnswer((_) async => const RunCaptureResult.pending());
    when(
      () => squadRepository.trackPresence(activity: any(named: 'activity')),
    ).thenAnswer((_) async {});
    when(
      () => squadRepository.broadcastTelemetry(label: any(named: 'label')),
    ).thenReturn(null);
  });

  tearDown(() async {
    if (!controller.isClosed) {
      await controller.close();
    }
  });

  RunTrackingCubit buildCubit() =>
      RunTrackingCubit(startRun, abandonRun, captureRun, watchRunState, squadRepository);

  test('initial state is const RunTrackState()', () async {
    final cubit = buildCubit();
    expect(cubit.state, const RunTrackState());
    await cubit.close();
  });

  test('begin subscribes and re-emits each state from watchRunState', () async {
    final cubit = buildCubit();
    final states = <RunTrackState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.begin();

    const s1 = RunTrackState(distanceMeters: 0);
    const s2 = RunTrackState(isTracking: true, distanceMeters: 100);
    controller.add(s1);
    await Future<void>.delayed(Duration.zero);
    controller.add(s2);
    await Future<void>.delayed(Duration.zero);

    expect(states, [s1, s2]);

    await sub.cancel();
    await cubit.close();
  });

  test(
    'trackPresence is called exactly once when tracking first starts, '
    'not again on subsequent tracking ticks',
    () async {
      final cubit = buildCubit();
      await cubit.begin();

      controller.add(const RunTrackState(isTracking: true, distanceMeters: 100));
      await Future<void>.delayed(Duration.zero);
      controller.add(const RunTrackState(isTracking: true, distanceMeters: 200));
      await Future<void>.delayed(Duration.zero);

      verify(() => squadRepository.trackPresence(activity: 'Running')).called(1);

      await cubit.close();
    },
  );

  test(
    'broadcastTelemetry is called on every tracking tick with a '
    'km-formatted label',
    () async {
      final cubit = buildCubit();
      await cubit.begin();

      controller.add(const RunTrackState(isTracking: true, distanceMeters: 1500));
      await Future<void>.delayed(Duration.zero);
      verify(
        () => squadRepository.broadcastTelemetry(label: 'Running · 1.5 km'),
      ).called(1);

      controller.add(const RunTrackState(isTracking: true, distanceMeters: 2000));
      await Future<void>.delayed(Duration.zero);
      verify(
        () => squadRepository.broadcastTelemetry(label: 'Running · 2.0 km'),
      ).called(1);

      await cubit.close();
    },
  );

  test(
    'neither trackPresence nor broadcastTelemetry is called when the '
    'state is not tracking',
    () async {
      final cubit = buildCubit();
      await cubit.begin();

      controller.add(const RunTrackState(distanceMeters: 500));
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

  test(
    'calling begin() again cancels the previous subscription and resets '
    'presence tracking for the new session',
    () async {
      final cubit = buildCubit();
      await cubit.begin();

      controller.add(const RunTrackState(isTracking: true, distanceMeters: 100));
      await Future<void>.delayed(Duration.zero);
      verify(() => squadRepository.trackPresence(activity: 'Running')).called(1);

      final controller2 = StreamController<RunTrackState>.broadcast();
      when(() => watchRunState()).thenAnswer((_) => controller2.stream);

      await cubit.begin();

      final states = <RunTrackState>[];
      final sub = cubit.stream.listen(states.add);

      // Old controller's events must no longer reach the cubit — the
      // previous subscription was cancelled by the second begin() call.
      controller.add(const RunTrackState(isTracking: true, distanceMeters: 999));
      await Future<void>.delayed(Duration.zero);
      expect(states, isEmpty);

      // New session: trackPresence fires again, proving _presenceTracked
      // was reset rather than staying latched from the first session.
      controller2.add(const RunTrackState(isTracking: true, distanceMeters: 50));
      await Future<void>.delayed(Duration.zero);

      verify(() => squadRepository.trackPresence(activity: 'Running')).called(1);
      expect(states, [const RunTrackState(isTracking: true, distanceMeters: 50)]);

      await sub.cancel();
      await controller2.close();
      await cubit.close();
    },
  );

  test('abandon delegates to AbandonRun with NoParams', () async {
    final cubit = buildCubit();

    await cubit.abandon();

    verify(() => abandonRun(const NoParams())).called(1);

    await cubit.close();
  });

  test('capture delegates to CaptureRun and returns its result', () async {
    const result = RunCaptureResult(
      pending: false,
      accepted: true,
      closedLoop: true,
      capturedAreaSqm: 100,
    );
    when(() => captureRun(const NoParams())).thenAnswer((_) async => result);

    final cubit = buildCubit();
    final actual = await cubit.capture();

    expect(actual, result);
    verify(() => captureRun(const NoParams())).called(1);

    await cubit.close();
  });

  group('close', () {
    test(
      'cancels the run-state subscription and abandons the run when '
      'still tracking',
      () async {
        final cubit = buildCubit();
        await cubit.begin();

        controller.add(const RunTrackState(isTracking: true, distanceMeters: 10));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isTracking, isTrue);

        await cubit.close();

        verify(() => abandonRun(const NoParams())).called(1);
      },
    );

    test('does not abandon the run when not tracking', () async {
      final cubit = buildCubit();
      await cubit.begin();

      // No tracking state was ever emitted — state stays at the default.
      expect(cubit.state.isTracking, isFalse);

      await cubit.close();

      verifyNever(() => abandonRun(const NoParams()));
    });
  });
}
