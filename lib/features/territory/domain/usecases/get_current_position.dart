import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/run_tracking_repository.dart';

@injectable
class GetCurrentPosition
    implements UseCase<({double latitude, double longitude})?, NoParams> {
  GetCurrentPosition(this._repository);

  final RunTrackingRepository _repository;

  @override
  Future<({double latitude, double longitude})?> call(NoParams params) =>
      _repository.getCurrentPosition();
}
