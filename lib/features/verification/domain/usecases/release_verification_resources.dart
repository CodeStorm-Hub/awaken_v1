import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/pose_verification_repository.dart';

@injectable
class ReleaseVerificationResources implements UseCase<void, NoParams> {
  ReleaseVerificationResources(this._repository);

  final PoseVerificationRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.releaseNativeResources();
}
