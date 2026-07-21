import 'package:injectable/injectable.dart';

import '../entities/verification_state.dart';
import '../repositories/pose_verification_repository.dart';

/// Stream-returning use case — skips the `UseCase<ReturnType, Params>`
/// interface per `core/usecase/usecase.dart`'s convention.
@injectable
class WatchVerificationState {
  WatchVerificationState(this._repository);

  final PoseVerificationRepository _repository;

  Stream<VerificationState> call() => _repository.watchState();
}
