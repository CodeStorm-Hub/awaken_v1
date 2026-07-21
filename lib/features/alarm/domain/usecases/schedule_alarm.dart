import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/alarm_schedule.dart';
import '../repositories/alarm_repository.dart';

@injectable
class ScheduleAlarm implements UseCase<void, AlarmSchedule> {
  ScheduleAlarm(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(AlarmSchedule params) => _repository.scheduleAlarm(params);
}
