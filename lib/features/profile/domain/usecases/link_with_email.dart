import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

@injectable
class LinkWithEmail {
  LinkWithEmail(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String email, required String password}) =>
      _repository.linkWithEmail(email: email, password: password);
}
