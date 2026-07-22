import '../entities/run_capture_result.dart';
import '../entities/run_track_state.dart';

/// Thrown by `startRun()` when location permission is permanently denied.
/// Distinct from `RunTrackState.permissionDenied` (which the repository
/// prefers to surface via state so the UI can render inline) — this is only
/// thrown for callers that need to react synchronously to the failure.
class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();
}

abstract interface class RunTrackingRepository {
  /// Live tracking state — idle (`isTracking: false`) until `startRun()`.
  Stream<RunTrackState> watchRunState();

  /// Begins GPS tracking: requests location permission if needed, starts the
  /// while-in-use location foreground service (plan H3), and begins
  /// EKF-smoothed position accumulation.
  Future<void> startRun();

  /// Stops tracking without persisting or submitting anything.
  Future<void> abandonRun();

  /// Stops tracking, simplifies and submits the path via `submit_run()`
  /// (server-authoritative — plan §3), and returns the result. Always
  /// persists locally first (outbox-durable) even if the submission itself
  /// can't complete immediately (offline).
  Future<RunCaptureResult> captureRun();
}
