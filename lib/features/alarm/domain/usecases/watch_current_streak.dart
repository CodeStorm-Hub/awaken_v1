import 'package:injectable/injectable.dart';

import '../repositories/alarm_repository.dart';

/// Stream-returning, so — per convention (see `WatchAlarms`) — this skips
/// the `UseCase<ReturnType, Params>` interface and just exposes `call()`.
@injectable
class WatchCurrentStreak {
  WatchCurrentStreak(this._repository);

  final AlarmRepository _repository;

  Stream<int> call() => _repository.watchCurrentStreak();
}
