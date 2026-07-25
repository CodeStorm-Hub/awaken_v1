import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

@injectable
class SendPasswordResetEmail {
  SendPasswordResetEmail(this._repository);

  final AuthRepository _repository;

  Future<void> call(String email) => _repository.sendPasswordResetEmail(email);
}
