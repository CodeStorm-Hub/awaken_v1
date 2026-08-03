import 'package:injectable/injectable.dart';

import '../repositories/auth_repository.dart';

@injectable
class LinkWithEmail {
  LinkWithEmail(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String email,
    required String password,
    required String displayName,
  }) => _repository.linkWithEmail(
    email: email,
    password: password,
    displayName: displayName,
  );
}
