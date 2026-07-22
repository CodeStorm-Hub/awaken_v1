import 'package:injectable/injectable.dart';

import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';

@LazySingleton(as: OnboardingRepository)
class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._local);

  final OnboardingLocalDataSource _local;

  @override
  Future<bool> hasSeenOnboarding() => _local.hasSeenOnboarding();

  @override
  Future<void> markOnboardingSeen() => _local.markOnboardingSeen();
}
