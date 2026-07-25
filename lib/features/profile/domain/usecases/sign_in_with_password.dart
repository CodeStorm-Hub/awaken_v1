import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

@injectable
class SignInWithPassword {
  SignInWithPassword(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String email, required String password}) =>
      _repository.signInWithPassword(email: email, password: password);
}
