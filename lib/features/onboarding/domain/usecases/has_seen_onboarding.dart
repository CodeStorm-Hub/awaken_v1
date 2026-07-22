import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/onboarding_repository.dart';

@injectable
class HasSeenOnboarding implements UseCase<bool, NoParams> {
  HasSeenOnboarding(this._repository);

  final OnboardingRepository _repository;

  @override
  Future<bool> call(NoParams params) => _repository.hasSeenOnboarding();
}
