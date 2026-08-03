import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/alarm_repository.dart';

@injectable
class EngageAlarmLockdown implements UseCase<void, NoParams> {
  EngageAlarmLockdown(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.engageRingLockdown();
}
