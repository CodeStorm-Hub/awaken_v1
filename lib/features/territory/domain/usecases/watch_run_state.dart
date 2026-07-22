import 'package:injectable/injectable.dart';

import '../entities/run_track_state.dart';
import '../repositories/run_tracking_repository.dart';

/// Stream-returning use case (skips `UseCase<ReturnType, Params>` per
/// core/usecase/usecase.dart's own doc comment).
@injectable
class WatchRunState {
  WatchRunState(this._repository);

  final RunTrackingRepository _repository;

  Stream<RunTrackState> call() => _repository.watchRunState();
}
