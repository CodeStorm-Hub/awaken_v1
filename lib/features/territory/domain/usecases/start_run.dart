import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/run_tracking_repository.dart';

@injectable
class StartRun implements UseCase<void, NoParams> {
  StartRun(this._repository);

  final RunTrackingRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.startRun();
}
