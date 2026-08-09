import 'package:equatable/equatable.dart';

import '../../../alarm/domain/entities/alarm_schedule.dart';
import 'body_pose.dart';
import 'rep_evidence.dart';

/// Number of clean reps required during calibration before counting
/// "for real" toward the target (plan §5 point 5 — "3-rep calibration
/// intro on first use").
const kCalibrationReps = 3;

/// Frames with average landmark confidence below this are treated as "no
/// usable pose" (low light, out of frame, camera occluded) rather than fed
/// into the rep-counting state machine.
const kMinPoseLikelihood = 0.6;

enum VerificationStatus {
  /// Camera/pose pipeline starting up.
  initializing,

  /// `Permission.camera` was denied — plan §5's "camera-permission-revoked"
  /// state, with a path back to the exercise itself never trapping the
  /// user (see `VerificationState.canFallBack`).
  permissionDenied,

  /// Average pose confidence is below [kMinPoseLikelihood] — plan §5's
  /// "low-light" state.
  noPoseDetected,

  /// User is doing the first [kCalibrationReps] reps before real counting
  /// starts, so the threshold isn't tripped by a rushed first rep.
  calibrating,

  /// Counting toward [VerificationState.targetReps].
  counting,

  /// Reached the target rep count.
  complete,

  /// Camera failed to start (no hardware, camera busy with another app, a
  /// plugin/platform error) — distinct from [permissionDenied], which is a
  /// user choice, not a failure. Never a dead end: same escape hatch as
  /// every other terminal-looking state, plus a retry.
  cameraError,
}

extension VerificationStatusX on VerificationStatus {
  /// Whether this status implies the camera/pose pipeline is actually
  /// running — used to decide whether an app-background lifecycle event
  /// has anything to pause (see `VerificationCubit.pause`).
  bool get isActiveCameraSession => switch (this) {
    VerificationStatus.initializing ||
    VerificationStatus.noPoseDetected ||
    VerificationStatus.calibrating ||
    VerificationStatus.counting => true,
    VerificationStatus.permissionDenied ||
    VerificationStatus.complete ||
    VerificationStatus.cameraError => false,
  };
}

class VerificationState extends Equatable {
  const VerificationState({
    this.status = VerificationStatus.initializing,
    this.exerciseMode = ExerciseMode.squat,
    this.targetReps = 0,
    this.completedReps = 0,
    this.calibrationRepsRemaining = kCalibrationReps,
    this.currentPose,
    this.repTrace = const [],
  });

  final VerificationStatus status;
  final ExerciseMode exerciseMode;
  final int targetReps;
  final int completedReps;
  final int calibrationRepsRemaining;

  /// Latest detected pose, for the skeleton overlay. Null when no pose is
  /// currently detected.
  final BodyPose? currentPose;

  /// Timing/angle evidence for every confirmed rep this session (including
  /// calibration reps) — submitted as [VerificationResult.repTrace] for
  /// server-side plausibility validation. See `RepEvidence`'s doc comment.
  final List<RepEvidence> repTrace;

  bool get isComplete => status == VerificationStatus.complete;

  VerificationState copyWith({
    VerificationStatus? status,
    ExerciseMode? exerciseMode,
    int? targetReps,
    int? completedReps,
    int? calibrationRepsRemaining,
    BodyPose? currentPose,
    bool clearPose = false,
    List<RepEvidence>? repTrace,
  }) {
    return VerificationState(
      status: status ?? this.status,
      exerciseMode: exerciseMode ?? this.exerciseMode,
      targetReps: targetReps ?? this.targetReps,
      completedReps: completedReps ?? this.completedReps,
      calibrationRepsRemaining:
          calibrationRepsRemaining ?? this.calibrationRepsRemaining,
      currentPose: clearPose ? null : (currentPose ?? this.currentPose),
      repTrace: repTrace ?? this.repTrace,
    );
  }

  @override
  List<Object?> get props => [
    status,
    exerciseMode,
    targetReps,
    completedReps,
    calibrationRepsRemaining,
    currentPose,
    repTrace,
  ];
}
