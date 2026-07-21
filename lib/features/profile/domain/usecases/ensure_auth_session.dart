import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

@injectable
class EnsureAuthSession implements UseCase<AppUser, NoParams> {
  EnsureAuthSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<AppUser> call(NoParams params) => _repository.ensureSession();
}
