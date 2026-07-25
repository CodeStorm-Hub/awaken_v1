import '../entities/alarm_schedule.dart';

abstract interface class AlarmRepository {
  /// All alarms currently scheduled on-device.
  Stream<List<AlarmSchedule>> watchAlarms();

  /// The alarm currently ringing, if any (null when nothing is ringing).
  /// `allowAlarmOverlap` is disabled, so at most one alarm rings at a time.
  Stream<AlarmSchedule?> watchRingingAlarm();

  Future<void> scheduleAlarm(AlarmSchedule alarm);
  Future<void> cancelAlarm(String id);

  /// Stops every natively-scheduled alarm without touching the local Drift
  /// cache — used only from account sign-out/switch/delete, immediately
  /// before `AppDatabase.clearAllLocalData()` wipes the alarms table.
  /// Without this, a stale scheduled alarm could still fire and reference
  /// now-wiped local data (e.g. `completeWorkout`'s session insert racing a
  /// wipe, or an alarm ringing for a session that's no longer this user's).
  Future<void> cancelAllAlarms();

  /// Engages Android screen pinning for as long as a real (non-preview)
  /// alarm is ringing — the strongest escape-blocking a normal Play Store
  /// app can do (no Device Owner/kiosk mode). Android-only; a no-op on iOS.
  /// Best-effort and never throws — the ring screen's own UI blocking
  /// (`PopScope`, full-screen overlay) is the load-bearing mechanism, this
  /// is additional hardening on top of it, not a replacement for it.
  Future<void> engageRingLockdown();

  /// Releases the screen pinning engaged by [engageRingLockdown]. Safe to
  /// call even if lockdown was never engaged (e.g. iOS, or the engage call
  /// itself failed).
  Future<void> releaseRingLockdown();

  /// Enable/disable an alarm without discarding its settings (unlike
  /// `cancelAlarm`, which deletes it outright). Disabling cancels the
  /// native schedule but keeps the alarm's config in the local cache so it
  /// can be re-armed later; `watchAlarms()` still shows it, greyed out.
  Future<void> setActive(String id, bool isActive);

  /// Stops the ringing alarm. Phase 1 scope only — this is a raw dismiss,
  /// not gated by exercise verification yet (that's Phase 4, plan §6).
  Future<void> dismissAlarm(String id);

  /// Ends the ring→verify loop (plan §6 Phase 4): stops the alarm
  /// regardless of outcome (the accessibility escape hatch — plan §5 point
  /// 5 — must never trap the user), logs a session, adjusts the global
  /// wake-up tax (reset on a verified completion, stepped up on a skip —
  /// see `watchCurrentTaxMultiplier`), and re-arms recurring alarms for
  /// their next occurrence.
  ///
  /// [isPreview] (P0 fix — "destructive preview"): when true, none of the
  /// above production side effects happen — no native stop of a real
  /// future alarm, no session logged, no tax mutation, no recurrence
  /// advance. `AlarmListPage`'s "tap one to preview the wake-up flow" opens
  /// a *real* alarm's `AlarmRingPage` to demo the ring→verify flow; without
  /// this flag, finishing or skipping that preview silently cancelled the
  /// real future occurrence, advanced its recurrence, logged a fake
  /// streak-eligible session, and reset/bumped the user's actual wake-up
  /// tax — all from what the user believed was a harmless demo.
  /// [startedAt] is when the user tapped "start workout" (verification
  /// began), not when it finished — recorded separately from the session's
  /// completion time so session duration is actually measurable.
  Future<void> completeWorkout(
    AlarmSchedule alarm, {
    required bool verified,
    required int repsCompleted,
    required DateTime startedAt,
    bool isPreview = false,
  });

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

  /// Re-arms any active alarm present in the local cache but not currently
  /// scheduled natively — the gap `reconcileRecurringAlarms` doesn't cover,
  /// since that one only fixes up alarms native already knows about.
  /// Needed after `PullDownSync` hydrates the local cache on a fresh
  /// install/new device, where nothing has been armed natively yet.
  Future<void> rearmFromCache();
}
