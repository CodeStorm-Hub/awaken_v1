import 'package:injectable/injectable.dart';

import '../entities/alarm_schedule.dart';
import '../repositories/alarm_repository.dart';

@injectable
class WatchAlarms {
  WatchAlarms(this._repository);

  final AlarmRepository _repository;

  Stream<List<AlarmSchedule>> call() => _repository.watchAlarms();
}
