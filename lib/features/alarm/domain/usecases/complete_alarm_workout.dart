import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/alarm_schedule.dart';
import '../repositories/alarm_repository.dart';

class CompleteAlarmWorkoutParams extends Equatable {
  const CompleteAlarmWorkoutParams({
    required this.alarm,
    required this.verified,
    required this.repsCompleted,
    required this.startedAt,
    this.isPreview = false,
  });

  final AlarmSchedule alarm;
  final bool verified;
  final int repsCompleted;
  final DateTime startedAt;
  final bool isPreview;

  @override
  List<Object?> get props => [
        alarm,
        verified,
        repsCompleted,
        startedAt,
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
        isPreview: params.isPreview,
      );
}
