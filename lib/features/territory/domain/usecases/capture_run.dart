import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/run_capture_result.dart';
import '../repositories/run_tracking_repository.dart';

@injectable
class CaptureRun implements UseCase<RunCaptureResult, NoParams> {
  CaptureRun(this._repository);

  final RunTrackingRepository _repository;

  @override
  Future<RunCaptureResult> call(NoParams params) => _repository.captureRun();
}
