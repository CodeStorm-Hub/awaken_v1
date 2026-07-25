import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:drift/drift.dart' show Value;
import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
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

  /// `Alarm.set()`/`Alarm.stop()` return `bool`, not `void` — a `false`
  /// result (native scheduling/cancellation actually failed on-device) was
  /// previously discarded everywhere, so cache/UI state could silently
  /// diverge from what the OS actually did. Every call site in this class
  /// goes through these two instead of calling `_local` directly.
  Future<void> _setNative(AlarmSettings settings) async {
    final ok = await _local.set(settings);
    if (!ok) {
      throw const AlarmOperationFailure('The device could not schedule this alarm');
    }
  }

  Future<void> _stopNative(int nativeId) async {
    final ok = await _local.stop(nativeId);
    if (!ok) {
      throw const AlarmOperationFailure('The device could not stop this alarm');
    }
  }

  /// Same native call as [_stopNative], but never throws. Used only from
  /// [completeWorkout], whose own accessibility guarantee (the ring screen
  /// "must never trap the user, verified or not" — see below) would be
  /// violated if a native-level stop failure blocked session recording and
  /// left the user stuck. The failure is still real and still worth
  /// knowing about — it just can't be allowed to halt this particular flow.
  Future<void> _stopNativeBestEffort(int nativeId) async {
    final ok = await _local.stop(nativeId);
    if (!ok) {
      unawaited(
        Sentry.captureMessage(
          'Native Alarm.stop() returned false during completeWorkout',
          level: SentryLevel.warning,
          withScope: (scope) => scope.setTag('nativeAlarmId', nativeId.toString()),
        ),
      );
    }
  }

  /// The stable, persisted native id for [alarmId] — computed once (via
  /// `AlarmPayload.deriveNativeId`) and read back from Drift on every
  /// subsequent call rather than recomputed, so it can never silently
  /// drift after an app/SDK update (see the `nativeId` column doc comment
  /// on `Alarms`). Backfills existing rows the first time they're touched
  /// post-migration.
  Future<int> _nativeIdFor(String alarmId) async {
    final row = await (_db.select(_db.alarms)..where((t) => t.id.equals(alarmId))).getSingleOrNull();
    if (row?.nativeId != null) return row!.nativeId!;
    final computed = AlarmPayload.deriveNativeId(alarmId);
    if (row != null) {
      await (_db.update(_db.alarms)..where((t) => t.id.equals(alarmId))).write(
        AlarmsCompanion(nativeId: Value(computed)),
      );
    }
    return computed;
  }

  String _titleFor(ExerciseMode mode) => switch (mode) {
        ExerciseMode.squat => 'Time to squat!',
        ExerciseMode.pushup => 'Time to push up!',
      };

  AlarmSettings _toAlarmSettings(AlarmSchedule alarm, int nativeId) {
    final payload = AlarmPayload(
      id: alarm.id,
      exerciseMode: alarm.exerciseMode,
      requiredReps: alarm.requiredReps,
      penaltyMultiplier: alarm.penaltyMultiplier,
      recurringDays: alarm.recurringDays,
    );

    return AlarmSettings(
      id: nativeId,
      dateTime: alarm.scheduledTime,
      loopAudio: true,
      vibrate: true,
      // Must survive the user swiping the app away from recents — this is
      // the whole point of the alarm being non-trivially dismissible
      // (plan C6/H1). The package's own default (true) would defeat it.
      androidStopAlarmOnTermination: false,
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      // Without this, two alarms scheduled for the same second can replace
      // one another instead of both ringing (package default is false).
      allowSameSecondScheduling: true,
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
    // AlarmPayload.fromJson uses unchecked casts/enum lookups and can throw
    // on a malformed or legacy-format payload. This runs inside a stream
    // `.map()` (watchAlarms()) — an uncaught throw here would kill the
    // whole native-alarm stream listener rather than just skipping one bad
    // row, taking down alarm scheduling/startup with it. Skip and report
    // instead; the caller already filters nulls via `.whereType()`.
    try {
      final payload = AlarmPayload.fromJson(settings.payload!);
      return AlarmSchedule(
        id: payload.id,
        scheduledTime: settings.dateTime,
        exerciseMode: payload.exerciseMode,
        requiredReps: payload.requiredReps,
        penaltyMultiplier: payload.penaltyMultiplier,
        recurringDays: payload.recurringDays,
      );
    } catch (e, st) {
      unawaited(Sentry.captureException(e, stackTrace: st));
      return null;
    }
  }

  AlarmSchedule _toAlarmScheduleFromRow(AlarmRow row) {
    return AlarmSchedule(
      id: row.id,
      scheduledTime: row.scheduledTime,
      exerciseMode: ExerciseMode.values.byName(row.exerciseMode),
      requiredReps: row.requiredReps,
      penaltyMultiplier: row.penaltyMultiplier,
      isActive: row.isActive,
      recurringDays: row.recurringDays.isEmpty
          ? const {}
          : row.recurringDays.split(',').map(int.parse).toSet(),
    );
  }

  /// Native `alarm` package scheduling stays the source of truth for
  /// anything currently armed (`isActive: true`, project convention —
  /// see `docs`/memory on recurrence). Disabled alarms are cancelled
  /// natively (so they can't ring) but must still show up in the list,
  /// greyed out — those come from the local Drift cache instead, since
  /// disabling removes them from the native `scheduled` set entirely.
  /// Hand-rolled combine-latest (no rxdart dependency, matching this
  /// project's "hand-rolled over heavy dependency" bias): re-emits the
  /// merged list whenever either source updates.
  @override
  Stream<List<AlarmSchedule>> watchAlarms() {
    late final StreamController<List<AlarmSchedule>> controller;
    List<AlarmSchedule> latestNative = const [];
    List<AlarmSchedule> latestDisabled = const [];
    var hasNative = false;
    var hasDisabled = false;

    void emitIfReady() {
      if (!hasNative || !hasDisabled) return;
      final disabledIds = latestDisabled.map((a) => a.id).toSet();
      final merged = [
        ...latestNative.where((a) => !disabledIds.contains(a.id)),
        ...latestDisabled,
      ]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      controller.add(merged);
    }

    late final StreamSubscription<List<AlarmSettings>> nativeSub;
    late final StreamSubscription<List<AlarmRow>> disabledSub;

    controller = StreamController<List<AlarmSchedule>>.broadcast(
      onListen: () {
        nativeSub = _local.scheduled.listen((settingsList) {
          latestNative = settingsList.map(_toAlarmSchedule).whereType<AlarmSchedule>().toList();
          hasNative = true;
          emitIfReady();
        });
        disabledSub = (_db.select(_db.alarms)
              ..where((t) => t.isActive.equals(false))
              ..where((t) => t.deletedAt.isNull()))
            .watch()
            .listen((rows) {
          latestDisabled = rows.map(_toAlarmScheduleFromRow).toList();
          hasDisabled = true;
          emitIfReady();
        });
      },
      onCancel: () {
        unawaited(nativeSub.cancel());
        unawaited(disabledSub.cancel());
      },
    );

    return controller.stream;
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    if (!isActive) {
      final nativeId = await _nativeIdFor(id);
      await _stopNative(nativeId);
      final row = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await _localWriter.upsertAlarm(
        id: row.id,
        nativeId: nativeId,
        scheduledTime: row.scheduledTime,
        exerciseMode: row.exerciseMode,
        requiredReps: row.requiredReps,
        penaltyMultiplier: row.penaltyMultiplier,
        isActive: false,
        recurringDays: row.recurringDays.isEmpty
            ? const {}
            : row.recurringDays.split(',').map(int.parse).toSet(),
      );
      return;
    }

    final row = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    var schedule = _toAlarmScheduleFromRow(row).copyWith(isActive: true);
    final now = DateTime.now();
    if (schedule.isRecurring && schedule.scheduledTime.isBefore(now)) {
      final next = schedule.nextOccurrenceAfter(now);
      if (next != null) schedule = schedule.copyWith(scheduledTime: next);
    }
    await scheduleAlarm(schedule);
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
    final nativeId = await _nativeIdFor(alarm.id);
    await _setNative(_toAlarmSettings(alarm, nativeId));
    await _localWriter.upsertAlarm(
      id: alarm.id,
      nativeId: nativeId,
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
    await _stopNative(await _nativeIdFor(id));
    await _localWriter.deleteAlarm(id);
  }

  @override
  Future<void> dismissAlarm(String id) async {
    await _stopNative(await _nativeIdFor(id));
  }

  @override
  Future<void> completeWorkout(
    AlarmSchedule alarm, {
    required bool verified,
    required int repsCompleted,
    required DateTime startedAt,
    bool isPreview = false,
  }) async {
    // P0 fix ("destructive preview"): a preview must not touch the native
    // alarm, local session log, wake-up tax, or recurrence — the alarm
    // passed in is a real scheduled alarm, so stopping it natively here
    // would cancel the user's actual future occurrence. See the interface
    // doc comment on `AlarmRepository.completeWorkout`.
    if (isPreview) return;

    final now = DateTime.now();

    // Stop the ring unconditionally — the accessibility escape hatch (plan
    // §5 point 5) must never trap the user, verified or not. Best-effort:
    // a native-level failure here is reported (see _stopNativeBestEffort)
    // but must not block the rest of this method.
    await _stopNativeBestEffort(await _nativeIdFor(alarm.id));

    await _localWriter.insertSession(
      id: const Uuid().v4(),
      alarmId: alarm.id,
      exerciseMode: alarm.exerciseMode.name,
      repsCompleted: repsCompleted,
      startedAt: startedAt,
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
    } else {
      // A one-shot alarm has nothing left to reschedule to and was just
      // stopped natively above — without this, its Drift row keeps
      // `isActive: true` forever (native no longer has it, so it vanishes
      // from `watchAlarms()`'s merged list, but the stale row lingers and
      // would report itself active to any direct query, e.g. a future
      // sync/backup read).
      final nativeId = await _nativeIdFor(alarm.id);
      await _localWriter.upsertAlarm(
        id: alarm.id,
        nativeId: nativeId,
        scheduledTime: alarm.scheduledTime,
        exerciseMode: alarm.exerciseMode.name,
        requiredReps: alarm.requiredReps,
        penaltyMultiplier: alarm.penaltyMultiplier,
        isActive: false,
        recurringDays: alarm.recurringDays,
      );
    }
  }

  @override
  Stream<double> watchCurrentTaxMultiplier() => _taxStore.watch();

  @override
  Future<void> reconcileRecurringAlarms() async {
    final now = DateTime.now();
    // A currently-ringing recurring alarm's stored scheduledTime is
    // necessarily in the past (that's why it's ringing) — without this
    // exclusion, reconciliation would reschedule it out from under itself
    // mid-ring instead of leaving that to completeWorkout's own
    // post-completion reschedule.
    final ringingId = (await watchRingingAlarm().first)?.id;
    final alarms = await watchAlarms().first;
    for (final alarm in alarms) {
      if (alarm.id == ringingId) continue;
      if (!alarm.isRecurring || !alarm.scheduledTime.isBefore(now)) continue;
      final next = alarm.nextOccurrenceAfter(now);
      if (next != null) {
        await scheduleAlarm(alarm.copyWith(scheduledTime: next));
      }
    }
  }

  @override
  Future<void> rearmFromCache() async {
    final armedIds = await _local.scheduled.first.then(
      (list) => list.map(_toAlarmSchedule).whereType<AlarmSchedule>().map((a) => a.id).toSet(),
    );
    final rows = await (_db.select(_db.alarms)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.deletedAt.isNull()))
        .get();

    final now = DateTime.now();
    for (final row in rows) {
      if (armedIds.contains(row.id)) continue;
      var schedule = _toAlarmScheduleFromRow(row);
      if (schedule.isRecurring && schedule.scheduledTime.isBefore(now)) {
        final next = schedule.nextOccurrenceAfter(now);
        if (next != null) schedule = schedule.copyWith(scheduledTime: next);
      } else if (!schedule.isRecurring && schedule.scheduledTime.isBefore(now)) {
        continue; // a past one-shot alarm has nothing sensible to re-arm to
      }
      await scheduleAlarm(schedule);
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
