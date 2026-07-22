import 'package:injectable/injectable.dart';

import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

@injectable
class WatchCurrentUser {
  WatchCurrentUser(this._repository);

  final AuthRepository _repository;

  /// Starts with the already-known current user (if any) so `ProfilePage`
  /// doesn't flash a "no user" state before the first `userChanges` event.
  Stream<AppUser?> call() async* {
    yield _repository.currentUser;
    yield* _repository.userChanges;
  }
}
