import 'package:equatable/equatable.dart';

import 'rep_evidence.dart';

/// What `VerificationPage` hands back to whoever pushed it (plan §6 Phase
/// 4). `completed: false` covers both the permission-denied and
/// "I can't do this exercise today" paths — both are the accessibility
/// escape hatch (plan §5 point 5: logged/streak-affecting, but never
/// trapping), just with a possibly-nonzero `repsCompleted` if the user had
/// already done some reps before backing out.
class VerificationResult extends Equatable {
  const VerificationResult({
    required this.completed,
    required this.repsCompleted,
    this.repTrace = const [],
  });

  final bool completed;
  final int repsCompleted;

  /// See `RepEvidence`'s doc comment — forwarded to
  /// `AlarmCubit.completeWorkout` for server-side plausibility validation.
  final List<RepEvidence> repTrace;

  @override
  List<Object?> get props => [completed, repsCompleted, repTrace];
}
