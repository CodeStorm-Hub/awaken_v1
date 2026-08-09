import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../verification/domain/entities/rep_evidence.dart';
import '../entities/alarm_schedule.dart';
import '../repositories/alarm_repository.dart';

class CompleteAlarmWorkoutParams extends Equatable {
  const CompleteAlarmWorkoutParams({
    required this.alarm,
    required this.verified,
    required this.repsCompleted,
    required this.startedAt,
    this.repTrace = const [],
    this.isPreview = false,
  });

  final AlarmSchedule alarm;
  final bool verified;
  final int repsCompleted;
  final DateTime startedAt;

  /// See `RepEvidence`'s doc comment — forwarded to
  /// `complete_workout_session()` for server-side plausibility validation.
  final List<RepEvidence> repTrace;

  /// See `AlarmRepository.completeWorkout`'s doc comment — must be true for
  /// `AlarmListPage`'s "tap to preview" flow, false for a real ring.
  final bool isPreview;

  @override
  List<Object?> get props => [
    alarm,
    verified,
    repsCompleted,
    startedAt,
    repTrace,
    isPreview,
  ];
}

@injectable
class CompleteAlarmWorkout
    implements UseCase<void, CompleteAlarmWorkoutParams> {
  CompleteAlarmWorkout(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(CompleteAlarmWorkoutParams params) =>
      _repository.completeWorkout(
        params.alarm,
        verified: params.verified,
        repsCompleted: params.repsCompleted,
        startedAt: params.startedAt,
        repTrace: params.repTrace,
        isPreview: params.isPreview,
      );
}
