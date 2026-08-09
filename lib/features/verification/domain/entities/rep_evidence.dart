import 'package:equatable/equatable.dart';

/// One confirmed rep's timing + joint-angle evidence, captured client-side
/// during verification and submitted to `complete_workout_session()` for
/// server-side plausibility validation (see that RPC's doc comment) —
/// closes the "fabricate a completed VerificationResult" trust gap without
/// requiring the alarm-dismissal flow itself to depend on a network call.
class RepEvidence extends Equatable {
  const RepEvidence({required this.confirmedAt, required this.angleDeg});

  /// Wall-clock time this rep's up-crossing was confirmed. Converted to an
  /// offset from the session's `startedAt` when submitted — never sent as
  /// an absolute timestamp, since only relative timing matters for the
  /// plausibility check.
  final DateTime confirmedAt;

  /// The joint angle (degrees) at the moment of confirmation — expected to
  /// sit near the exercise's up-threshold (see `AngleRepCounter`).
  final double angleDeg;

  @override
  List<Object?> get props => [confirmedAt, angleDeg];
}
