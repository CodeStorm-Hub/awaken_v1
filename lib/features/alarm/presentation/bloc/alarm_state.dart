import 'package:equatable/equatable.dart';

import '../../domain/entities/alarm_schedule.dart';

class AlarmState extends Equatable {
  const AlarmState({
    this.alarms = const [],
    this.ringingAlarm,
    this.currentTaxMultiplier = 1.0,
    this.verificationInProgress = false,
  });

  final List<AlarmSchedule> alarms;
  final AlarmSchedule? ringingAlarm;

  /// The global wake-up tax (plan discussion — per-user, not per-alarm).
  final double currentTaxMultiplier;

  /// True while `AlarmRingPage._startWorkout` has pushed `VerificationPage`
  /// onto the root `Navigator` and is awaiting its result. Real bug found
  /// live: `_AlarmRingOverlay` in `app.dart` unconditionally repaints its
  /// own `AlarmRingPage` on top of the Navigator whenever `ringingAlarm !=
  /// null`, with no awareness of what's been pushed underneath — so the
  /// pushed `VerificationPage` was running (camera + ML Kit both active,
  /// confirmed via logcat) but permanently invisible, since the overlay
  /// always wins the paint order. A deadlock: the verification UI can never
  /// be interacted with, so the alarm can never be dismissed, so the
  /// overlay never goes away. This flag lets the overlay step aside while a
  /// verification attempt from the ringing alarm itself is in flight.
  final bool verificationInProgress;

  AlarmState copyWith({
    List<AlarmSchedule>? alarms,
    // Distinguishes "leave unchanged" from "explicitly clear to null".
    Object? ringingAlarm = _unset,
    double? currentTaxMultiplier,
    bool? verificationInProgress,
  }) {
    return AlarmState(
      alarms: alarms ?? this.alarms,
      ringingAlarm: identical(ringingAlarm, _unset)
          ? this.ringingAlarm
          : ringingAlarm as AlarmSchedule?,
      currentTaxMultiplier: currentTaxMultiplier ?? this.currentTaxMultiplier,
      verificationInProgress:
          verificationInProgress ?? this.verificationInProgress,
    );
  }

  static const _unset = Object();

  @override
  List<Object?> get props => [
    alarms,
    ringingAlarm,
    currentTaxMultiplier,
    verificationInProgress,
  ];
}
