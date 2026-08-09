import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../../squad/domain/repositories/squad_repository.dart';
import '../../domain/entities/verification_state.dart';
import '../../domain/usecases/release_verification_resources.dart';
import '../../domain/usecases/start_verification_session.dart';
import '../../domain/usecases/stop_verification_session.dart';
import '../../domain/usecases/watch_verification_state.dart';

/// Per-session Cubit (not app-wide like `AlarmCubit`) — created fresh each
/// time `VerificationPage` opens and disposed with it, since a pose
/// verification session is scoped to one workout, not the whole app
/// lifetime.
@injectable
class VerificationCubit extends Cubit<VerificationState> {
  VerificationCubit(
    this._startSession,
    this._stopSession,
    this._watchState,
    this._releaseResources,
    this._squadRepository,
  ) : super(const VerificationState());

  final StartVerificationSession _startSession;
  final StopVerificationSession _stopSession;
  final WatchVerificationState _watchState;
  final ReleaseVerificationResources _releaseResources;

  /// Squad-telemetry broadcast (plan §6 Phase 6, H6) — throttled and a
  /// no-op internally when the user has no squad.
  final SquadRepository _squadRepository;

  /// Never stored/cancelled before this fix — a retried `begin()` (e.g.
  /// after `permissionDenied`) would stack another listener onto the
  /// repository's state stream, same class of bug as
  /// `RunTrackingCubit._runStateSub` (see that fix's doc comment).
  StreamSubscription<VerificationState>? _stateSub;

  /// `trackPresence` does a real Realtime round-trip — call it once per
  /// session, not on every state tick.
  var _presenceTracked = false;

  ExerciseMode? _lastExercise;
  int? _lastTargetReps;

  /// Set while the camera session has been torn down for an app
  /// backgrounding (`pause()`), not a real failure or user exit — `resume()`
  /// only re-starts the camera when this is true, so foregrounding the app
  /// on an already-`permissionDenied`/`complete` screen doesn't spuriously
  /// restart anything.
  var _pausedForLifecycle = false;

  Future<void> begin({
    required ExerciseMode exercise,
    required int targetReps,
  }) async {
    _lastExercise = exercise;
    _lastTargetReps = targetReps;
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      emit(state.copyWith(status: VerificationStatus.permissionDenied));
      return;
    }

    await WakelockPlus.enable();
    await _stateSub?.cancel();
    _presenceTracked = false;
    _stateSub = _watchState().listen((state) {
      emit(state);
      if (state.status == VerificationStatus.counting ||
          state.status == VerificationStatus.calibrating) {
        if (!_presenceTracked) {
          _presenceTracked = true;
          unawaited(_squadRepository.trackPresence(activity: 'Working out'));
        }
        final label = state.exerciseMode == ExerciseMode.squat
            ? 'squats'
            : 'push-ups';
        _squadRepository.broadcastTelemetry(
          label: 'Workout · ${state.completedReps}/${state.targetReps} $label',
        );
      }
    });
    try {
      await _startSession(
        StartVerificationParams(exercise: exercise, targetReps: targetReps),
      );
    } catch (_) {
      // The repository already catches and reports the camera-init path
      // itself (emitting `cameraError`) — this is a backstop for anything
      // else in the start path (e.g. `availableCameras()` throwing on a
      // camera-less device), so `begin()` never lets an exception escape
      // uncaught into `VerificationPage`'s `create:` callback.
      emit(
        state.copyWith(
          status: VerificationStatus.cameraError,
          exerciseMode: exercise,
          targetReps: targetReps,
        ),
      );
    }
  }

  /// Retries after a [VerificationStatus.cameraError] with the same
  /// exercise/target-reps this session was opened with.
  Future<void> retry() async {
    final exercise = _lastExercise;
    final targetReps = _lastTargetReps;
    if (exercise == null || targetReps == null) return;
    await begin(exercise: exercise, targetReps: targetReps);
  }

  /// Releases the camera when the app is backgrounded (`AppLifecycleState
  /// .inactive`/`.paused`) — holding an active `CameraController` while
  /// backgrounded is a known crash/resource-conflict risk on Android per
  /// `package:camera`'s own guidance, and iOS can kill a backgrounded
  /// camera session outright. Only acts on a genuinely active session —
  /// `permissionDenied`/`cameraError`/`complete` have nothing to release.
  Future<void> pause() async {
    if (!state.status.isActiveCameraSession) return;
    _pausedForLifecycle = true;
    await _stopSession(const NoParams());
  }

  /// Counterpart to [pause] — restarts the camera session with the same
  /// parameters once the app is foregrounded again.
  Future<void> resume() async {
    if (!_pausedForLifecycle) return;
    _pausedForLifecycle = false;
    await retry();
  }

  /// Only meaningful on `AppLifecycleState.detached` — see
  /// [ReleaseVerificationResources]'s repository method doc comment.
  Future<void> releaseNativeResources() => _releaseResources(const NoParams());

  @override
  Future<void> close() async {
    await _stateSub?.cancel();
    // Fire-and-forget: camera teardown (stopImageStream + dispose) is native
    // work that can take a noticeable moment on both CameraX and AVFoundation
    // backends. Awaiting it here ties that cost to whatever triggered this
    // close (typically a Navigator.pop), landing on the same frame as the
    // page transition. The repository's `_generation` guard already discards
    // any frame that straggles in after this point, so there's nothing for
    // the caller to wait on.
    unawaited(_stopSession(const NoParams()));
    await WakelockPlus.disable();
    return super.close();
  }
}
