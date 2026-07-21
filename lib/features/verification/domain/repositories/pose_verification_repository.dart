import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../entities/verification_state.dart';

abstract interface class PoseVerificationRepository {
  Stream<VerificationState> watchState();

  /// Starts the camera + pose pipeline for [exercise], counting up to
  /// [targetReps]. No-op if a session is already running.
  Future<void> start({required ExerciseMode exercise, required int targetReps});

  /// Stops the camera + pose pipeline and releases the camera.
  Future<void> stop();
}
