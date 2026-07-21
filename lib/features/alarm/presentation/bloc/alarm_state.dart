import 'package:equatable/equatable.dart';

import '../../domain/entities/alarm_schedule.dart';

class AlarmState extends Equatable {
  const AlarmState({
    this.alarms = const [],
    this.ringingAlarm,
    this.currentTaxMultiplier = 1.0,
  });

  final List<AlarmSchedule> alarms;
  final AlarmSchedule? ringingAlarm;

  /// The global wake-up tax (plan discussion — per-user, not per-alarm).
  final double currentTaxMultiplier;

  AlarmState copyWith({
    List<AlarmSchedule>? alarms,
    // Distinguishes "leave unchanged" from "explicitly clear to null".
    Object? ringingAlarm = _unset,
    double? currentTaxMultiplier,
  }) {
    return AlarmState(
      alarms: alarms ?? this.alarms,
      ringingAlarm: identical(ringingAlarm, _unset)
          ? this.ringingAlarm
          : ringingAlarm as AlarmSchedule?,
      currentTaxMultiplier: currentTaxMultiplier ?? this.currentTaxMultiplier,
    );
  }

  static const _unset = Object();

  @override
  List<Object?> get props => [alarms, ringingAlarm, currentTaxMultiplier];
}
