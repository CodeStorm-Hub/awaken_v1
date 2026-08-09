import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../entities/verification_state.dart';

abstract interface class PoseVerificationRepository {
  Stream<VerificationState> watchState();

  /// Starts the camera + pose pipeline for [exercise], counting up to
  /// [targetReps]. No-op if a session is already running.
  Future<void> start({required ExerciseMode exercise, required int targetReps});

  /// Stops the camera + pose pipeline and releases the camera.
  Future<void> stop();

  /// Releases the underlying ML Kit pose detector's native resources.
  /// Call only when the process is genuinely tearing down (app-detached) —
  /// the detector is a process-lifetime singleton reused across every
  /// verification session, and processing a frame after this call throws.
  Future<void> releaseNativeResources();
}
