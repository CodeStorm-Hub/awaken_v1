import 'package:alarm/alarm.dart';
import 'package:injectable/injectable.dart';

/// Thin wrapper over the static `Alarm` class from package:alarm — the
/// only place in the app that touches it directly. `Alarm.init()` also
/// reschedules any alarms persisted from a previous session (boot/kill
/// restore is handled by the package itself, per its `checkAlarm()` — see
/// pub cache alarm-5.5.0/lib/alarm.dart).
@lazySingleton
class AlarmLocalDataSource {
  Future<void> init() => Alarm.init();

  Stream<List<AlarmSettings>> get scheduled =>
      Alarm.scheduled.map((set) => set.alarms.toList());

  Stream<List<AlarmSettings>> get ringing =>
      Alarm.ringing.map((set) => set.alarms.toList());

  Future<bool> set(AlarmSettings settings) => Alarm.set(alarmSettings: settings);

  Future<bool> stop(int id) => Alarm.stop(id);

  Future<void> stopAll() => Alarm.stopAll();
}
