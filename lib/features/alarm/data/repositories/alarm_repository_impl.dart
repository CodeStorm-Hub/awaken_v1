import 'package:alarm/alarm.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../sync/local/database.dart';
import '../../../../sync/outbox/local_writer.dart';
import '../../domain/entities/alarm_schedule.dart';
import '../../domain/repositories/alarm_repository.dart';
import '../datasources/alarm_local_datasource.dart';
import '../datasources/wake_up_tax_store.dart';
import '../models/alarm_payload.dart';

@LazySingleton(as: AlarmRepository)
class AlarmRepositoryImpl implements AlarmRepository {
  AlarmRepositoryImpl(this._local, this._localWriter, this._db, this._taxStore);

  final AlarmLocalDataSource _local;

  /// Cross-device backup of the schedule (plan §3 sync engine ownership).
  /// The native `alarm` package (`_local`) stays the source of truth for
  /// *ringing behavior* — this is purely so a signed-in user's alarms
  /// survive a reinstall/new device.
  final LocalWriter _localWriter;

  /// Read-only access to the local session log for `watchCurrentStreak` —
  /// `LocalWriter` is write-only by design (plan §3), so reads go straight
  /// to the database like any other feature would.
  final AppDatabase _db;

  final WakeUpTaxStore _taxStore;

  String _titleFor(ExerciseMode mode) => switch (mode) {
        ExerciseMode.squat => 'Time to squat!',
        ExerciseMode.pushup => 'Time to push up!',
      };

  AlarmSettings _toAlarmSettings(AlarmSchedule alarm) {
    final payload = AlarmPayload(
      id: alarm.id,
      exerciseMode: alarm.exerciseMode,
      requiredReps: alarm.requiredReps,
      penaltyMultiplier: alarm.penaltyMultiplier,
      recurringDays: alarm.recurringDays,
    );

    return AlarmSettings(
      id: AlarmPayload.nativeId(alarm.id),
      dateTime: alarm.scheduledTime,
      loopAudio: true,
      vibrate: true,
      // Must survive the user swiping the app away from recents — this is
      // the whole point of the alarm being non-trivially dismissible
      // (plan C6/H1). The package's own default (true) would defeat it.
      androidStopAlarmOnTermination: false,
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fixed(volume: 1, volumeEnforced: true),
      notificationSettings: NotificationSettings(
        title: _titleFor(alarm.exerciseMode),
        body: '${alarm.requiredReps} reps to dismiss.',
        // No stop button: the whole mechanic is that a notification swipe
        // shouldn't be enough to dismiss (plan §2.3 moderate — "hard limits"
        // on true non-dismissibility are accepted, but we don't hand the
        // user a trivial one-tap out either).
      ),
      payload: payload.toJson(),
    );
  }

  AlarmSchedule? _toAlarmSchedule(AlarmSettings settings) {
    if (settings.payload == null) return null;
    final payload = AlarmPayload.fromJson(settings.payload!);
    return AlarmSchedule(
      id: payload.id,
      scheduledTime: settings.dateTime,
      exerciseMode: payload.exerciseMode,
      requiredReps: payload.requiredReps,
      penaltyMultiplier: payload.penaltyMultiplier,
      recurringDays: payload.recurringDays,
    );
  }

  @override
  Stream<List<AlarmSchedule>> watchAlarms() {
    return _local.scheduled.map(
      (settingsList) => settingsList.map(_toAlarmSchedule).whereType<AlarmSchedule>().toList(),
    );
  }

  @override
  Stream<AlarmSchedule?> watchRingingAlarm() {
    return _local.ringing.map((settingsList) {
      if (settingsList.isEmpty) return null;
      return _toAlarmSchedule(settingsList.first);
    });
  }

  @override
  Future<void> scheduleAlarm(AlarmSchedule alarm) async {
    await _local.set(_toAlarmSettings(alarm));
    await _localWriter.upsertAlarm(
      id: alarm.id,
      scheduledTime: alarm.scheduledTime,
      exerciseMode: alarm.exerciseMode.name,
      requiredReps: alarm.requiredReps,
      penaltyMultiplier: alarm.penaltyMultiplier,
      isActive: alarm.isActive,
      recurringDays: alarm.recurringDays,
    );
  }

  @override
  Future<void> cancelAlarm(String id) async {
    await _local.stop(AlarmPayload.nativeId(id));
    await _localWriter.deleteAlarm(id);
  }

  @override
  Future<void> dismissAlarm(String id) async {
    await _local.stop(AlarmPayload.nativeId(id));
  }

  @override
  Future<void> completeWorkout(
    AlarmSchedule alarm, {
    required bool verified,
    required int repsCompleted,
  }) async {
    final now = DateTime.now();

    // Stop the ring unconditionally — the accessibility escape hatch (plan
    // §5 point 5) must never trap the user, verified or not.
    await _local.stop(AlarmPayload.nativeId(alarm.id));

    await _localWriter.insertSession(
      id: const Uuid().v4(),
      alarmId: alarm.id,
      exerciseMode: alarm.exerciseMode.name,
      repsCompleted: repsCompleted,
      startedAt: now,
      completedAt: verified ? now : null,
    );

    // Global wake-up tax (plan discussion) — reset on a verified
    // completion, step up on a skip.
    if (verified) {
      await _taxStore.reset();
    } else {
      await _taxStore.bump();
    }

    // Re-arm recurring alarms for their next occurrence (plan discussion —
    // "one-at-a-time" common path; `reconcileRecurringAlarms` is the
    // self-heal backstop for when this step never runs).
    if (alarm.isRecurring) {
      final next = alarm.nextOccurrenceAfter(now);
      if (next != null) {
        await scheduleAlarm(alarm.copyWith(scheduledTime: next));
      }
    }
  }

  @override
  Stream<double> watchCurrentTaxMultiplier() => _taxStore.watch();

  @override
  Future<void> reconcileRecurringAlarms() async {
    final now = DateTime.now();
    final alarms = await watchAlarms().first;
    for (final alarm in alarms) {
      if (!alarm.isRecurring || !alarm.scheduledTime.isBefore(now)) continue;
      final next = alarm.nextOccurrenceAfter(now);
      if (next != null) {
        await scheduleAlarm(alarm.copyWith(scheduledTime: next));
      }
    }
  }

  @override
  Stream<int> watchCurrentStreak() {
    return _db.select(_db.sessions).watch().map(_computeStreak);
  }

  int _computeStreak(List<SessionRow> sessions) {
    final completedDays = sessions
        .where((s) => s.completedAt != null)
        .map((s) => DateTime(s.completedAt!.year, s.completedAt!.month, s.completedAt!.day))
        .toSet();

    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    // Today not having a session yet shouldn't zero out yesterday's streak
    // mid-day — only fall back to "yesterday" as the walk's starting point.
    if (!completedDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (completedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
