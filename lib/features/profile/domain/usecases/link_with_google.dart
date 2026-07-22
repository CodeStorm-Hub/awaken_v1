import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

@injectable
class LinkWithGoogle implements UseCase<void, NoParams> {
  LinkWithGoogle(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.linkWithGoogle();
}
