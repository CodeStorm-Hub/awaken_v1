import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/onboarding_repository.dart';

@injectable
class MarkOnboardingSeen implements UseCase<void, NoParams> {
  MarkOnboardingSeen(this._repository);

  final OnboardingRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.markOnboardingSeen();
}
