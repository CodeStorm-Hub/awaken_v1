import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

@injectable
class RefreshAuthSession implements UseCase<void, NoParams> {
  RefreshAuthSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.refreshSession();
}
