import 'package:injectable/injectable.dart';

import '../entities/alarm_schedule.dart';
import '../repositories/alarm_repository.dart';

@injectable
class WatchRingingAlarm {
  WatchRingingAlarm(this._repository);

  final AlarmRepository _repository;

  Stream<AlarmSchedule?> call() => _repository.watchRingingAlarm();
}
