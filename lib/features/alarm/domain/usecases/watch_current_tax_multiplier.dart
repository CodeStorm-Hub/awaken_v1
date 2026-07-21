import 'package:injectable/injectable.dart';

import '../repositories/alarm_repository.dart';

/// Stream-returning, so — per convention (see `WatchAlarms`) — this skips
/// the `UseCase<ReturnType, Params>` interface and just exposes `call()`.
@injectable
class WatchCurrentTaxMultiplier {
  WatchCurrentTaxMultiplier(this._repository);

  final AlarmRepository _repository;

  Stream<double> call() => _repository.watchCurrentTaxMultiplier();
}
