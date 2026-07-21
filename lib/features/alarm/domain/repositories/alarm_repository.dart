import '../entities/alarm_schedule.dart';

abstract interface class AlarmRepository {
  /// All alarms currently scheduled on-device.
  Stream<List<AlarmSchedule>> watchAlarms();

  /// The alarm currently ringing, if any (null when nothing is ringing).
  /// `allowAlarmOverlap` is disabled, so at most one alarm rings at a time.
  Stream<AlarmSchedule?> watchRingingAlarm();

  Future<void> scheduleAlarm(AlarmSchedule alarm);
  Future<void> cancelAlarm(String id);

  /// Stops the ringing alarm. Phase 1 scope only — this is a raw dismiss,
  /// not gated by exercise verification yet (that's Phase 4, plan §6).
  Future<void> dismissAlarm(String id);

  /// Ends the ring→verify loop (plan §6 Phase 4): stops the alarm
  /// regardless of outcome (the accessibility escape hatch — plan §5 point
  /// 5 — must never trap the user), logs a session, adjusts the global
  /// wake-up tax (reset on a verified completion, stepped up on a skip —
  /// see `watchCurrentTaxMultiplier`), and re-arms recurring alarms for
  /// their next occurrence.
  Future<void> completeWorkout(AlarmSchedule alarm, {required bool verified, required int repsCompleted});

  /// Consecutive days (ending today or yesterday) with at least one
  /// verified completion, computed from the local session log.
  Stream<int> watchCurrentStreak();

  /// The current wake-up tax multiplier (plan discussion: per-user, not
  /// per-alarm, so it can't be reset by deleting and recreating an alarm).
  Stream<double> watchCurrentTaxMultiplier();

  /// Self-heal for recurring alarms (plan discussion — the "hybrid"
  /// rescheduling approach): re-arms any recurring alarm whose stored
  /// `scheduledTime` has already passed, which only happens if the
  /// post-ring reschedule in `completeWorkout` never ran (app killed,
  /// crashed, etc). Call once on app launch.
  Future<void> reconcileRecurringAlarms();
}
