import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/pose_verification_repository.dart';

@injectable
class StopVerificationSession implements UseCase<void, NoParams> {
  StopVerificationSession(this._repository);

  final PoseVerificationRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.stop();
}
