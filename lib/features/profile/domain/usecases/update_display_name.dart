import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

@injectable
class UpdateDisplayName {
  UpdateDisplayName(this._repository);

  final AuthRepository _repository;

  Future<void> call(String name) => _repository.updateDisplayName(name);
}
