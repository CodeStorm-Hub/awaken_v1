import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/run_tracking_repository.dart';

@injectable
class AbandonRun implements UseCase<void, NoParams> {
  AbandonRun(this._repository);

  final RunTrackingRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.abandonRun();
}
