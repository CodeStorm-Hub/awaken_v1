import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

@injectable
class DeleteAccount implements UseCase<void, NoParams> {
  DeleteAccount(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.deleteAccount();
}
