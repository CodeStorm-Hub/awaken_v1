import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/alarm_repository.dart';

/// Call once after `PullDownSync` (plan §6 Phase 6.5) — re-arms natively
/// any active alarm the pull hydrated into the local cache but that isn't
/// scheduled yet.
@injectable
class RearmAlarmsFromCache implements UseCase<void, NoParams> {
  RearmAlarmsFromCache(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.rearmFromCache();
}
