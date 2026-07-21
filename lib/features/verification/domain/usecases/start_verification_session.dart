import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../repositories/pose_verification_repository.dart';

class StartVerificationParams extends Equatable {
  const StartVerificationParams({required this.exercise, required this.targetReps});

  final ExerciseMode exercise;
  final int targetReps;

  @override
  List<Object?> get props => [exercise, targetReps];
}

@injectable
class StartVerificationSession implements UseCase<void, StartVerificationParams> {
  StartVerificationSession(this._repository);

  final PoseVerificationRepository _repository;

  @override
  Future<void> call(StartVerificationParams params) =>
      _repository.start(exercise: params.exercise, targetReps: params.targetReps);
}
