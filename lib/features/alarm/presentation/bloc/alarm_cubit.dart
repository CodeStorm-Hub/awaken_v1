import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/alarm_schedule.dart';
import '../../domain/usecases/cancel_alarm.dart';
import '../../domain/usecases/complete_alarm_workout.dart';
import '../../domain/usecases/dismiss_alarm.dart';
import '../../domain/usecases/schedule_alarm.dart';
import '../../domain/usecases/watch_alarms.dart';
import '../../domain/usecases/watch_current_tax_multiplier.dart';
import '../../domain/usecases/watch_ringing_alarm.dart';
import 'alarm_state.dart';

/// App-wide alarm state — ringing status must be observable regardless of
/// which screen is on top, so this is a singleton, not a per-page Cubit.
@lazySingleton
class AlarmCubit extends Cubit<AlarmState> {
  AlarmCubit(
    this._watchAlarms,
    this._watchRingingAlarm,
    this._scheduleAlarm,
    this._cancelAlarm,
    this._dismissAlarm,
    this._completeWorkout,
    this._watchCurrentTaxMultiplier,
  ) : super(const AlarmState()) {
    _alarmsSub = _watchAlarms().listen((alarms) => emit(state.copyWith(alarms: alarms)));
    _ringingSub =
        _watchRingingAlarm().listen((ringing) => emit(state.copyWith(ringingAlarm: ringing)));
    _taxSub = _watchCurrentTaxMultiplier()
        .listen((tax) => emit(state.copyWith(currentTaxMultiplier: tax)));
  }

  final WatchAlarms _watchAlarms;
  final WatchRingingAlarm _watchRingingAlarm;
  final ScheduleAlarm _scheduleAlarm;
  final CancelAlarm _cancelAlarm;
  final DismissAlarm _dismissAlarm;
  final CompleteAlarmWorkout _completeWorkout;
  final WatchCurrentTaxMultiplier _watchCurrentTaxMultiplier;

  late final StreamSubscription<List<AlarmSchedule>> _alarmsSub;
  late final StreamSubscription<AlarmSchedule?> _ringingSub;
  late final StreamSubscription<double> _taxSub;

  Future<void> schedule(AlarmSchedule alarm) => _scheduleAlarm(alarm);
  Future<void> cancel(String id) => _cancelAlarm(id);
  Future<void> dismiss(String id) => _dismissAlarm(id);

  Future<void> completeWorkout(
    AlarmSchedule alarm, {
    required bool verified,
    required int repsCompleted,
  }) => _completeWorkout(
    CompleteAlarmWorkoutParams(alarm: alarm, verified: verified, repsCompleted: repsCompleted),
  );

  @override
  Future<void> close() async {
    await _alarmsSub.cancel();
    await _ringingSub.cancel();
    await _taxSub.cancel();
    return super.close();
  }
}
