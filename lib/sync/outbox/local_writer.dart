import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../local/database.dart';
import 'outbox_operation.dart';

/// The single write seam `sync/` exposes to features (plan §3 — "sync
/// engine ownership"): every domain write and its `sync_outbox` enqueue
/// happen in one Drift transaction, so there is no code path that writes
/// local data without also queuing it for upload. Features never touch
/// Supabase directly for user data — only this class and `SyncWorker` do.
@lazySingleton
class LocalWriter {
  LocalWriter(this._db);

  final AppDatabase _db;

  Future<void> upsertAlarm({
    required String id,
    required int nativeId,
    required DateTime scheduledTime,
    required String exerciseMode,
    required int requiredReps,
    required double penaltyMultiplier,
    required bool isActive,
    Set<int> recurringDays = const {},
  }) {
    final now = DateTime.now();
    return _db.transaction(() async {
      await _db.into(_db.alarms).insertOnConflictUpdate(
            AlarmsCompanion.insert(
              id: id,
              nativeId: Value(nativeId),
              scheduledTime: scheduledTime,
              exerciseMode: exerciseMode,
              requiredReps: requiredReps,
              penaltyMultiplier: Value(penaltyMultiplier),
              isActive: Value(isActive),
              recurringDays: Value(recurringDays.join(',')),
              updatedAt: now,
            ),
          );
      await _enqueue(
        table: 'alarms',
        entityId: id,
        operation: OutboxOperation.upsert,
        payload: {
          'id': id,
          'scheduled_time': scheduledTime.toIso8601String(),
          'exercise_mode': exerciseMode,
          'required_reps': requiredReps,
          'penalty_multiplier': penaltyMultiplier,
          'is_active': isActive,
          'updated_at': now.toIso8601String(),
          'recurring_days': recurringDays.join(','),
        },
      );
    });
  }

  Future<void> deleteAlarm(String id) {
    final now = DateTime.now();
    return _db.transaction(() async {
      await (_db.update(_db.alarms)..where((t) => t.id.equals(id))).write(
        AlarmsCompanion(deletedAt: Value(now), isActive: const Value(false), updatedAt: Value(now)),
      );
      await _enqueue(table: 'alarms', entityId: id, operation: OutboxOperation.delete, payload: const {});
    });
  }

  /// Append-only — verification sessions are never edited after logging
  /// (plan §6 Phase 4).
  Future<void> insertSession({
    required String id,
    String? alarmId,
    required String exerciseMode,
    required int repsCompleted,
    required DateTime startedAt,
    DateTime? completedAt,
  }) {
    final now = DateTime.now();
    return _db.transaction(() async {
      await _db.into(_db.sessions).insert(
            SessionsCompanion.insert(
              id: id,
              alarmId: Value(alarmId),
              exerciseMode: exerciseMode,
              repsCompleted: repsCompleted,
              startedAt: startedAt,
              completedAt: Value(completedAt),
              updatedAt: now,
            ),
          );
      await _enqueue(
        table: 'sessions',
        entityId: id,
        operation: OutboxOperation.upsert,
        payload: {
          'id': id,
          'alarm_id': alarmId,
          'exercise_mode': exerciseMode,
          'reps_completed': repsCompleted,
          'started_at': startedAt.toIso8601String(),
          'completed_at': completedAt?.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
      );
    });
  }

  /// Append-only — territory capture is server-computed from the submitted
  /// path via `submit_run()`; this row is the client's record of having
  /// submitted, not the authoritative result (plan §6 Phase 5).
  Future<void> insertRun({
    required String id,
    required DateTime startedAt,
    DateTime? endedAt,
    required int pointCount,
    required String pathGeoJson,
    String? pointTimestampsJson,
  }) {
    final now = DateTime.now();
    return _db.transaction(() async {
      await _db.into(_db.runs).insert(
            RunsCompanion.insert(
              id: id,
              startedAt: startedAt,
              endedAt: Value(endedAt),
              pointCount: pointCount,
              pathGeoJson: pathGeoJson,
              pointTimestampsJson: Value(pointTimestampsJson),
              updatedAt: now,
            ),
          );
      await _enqueue(
        table: 'runs',
        entityId: id,
        operation: OutboxOperation.upsert,
        payload: {
          'id': id,
          // `.toUtc()` is load-bearing, not cosmetic: `submit_run()` compares
          // these against each GPS fix's timestamp (already UTC — geolocator
          // returns UTC `Position.timestamp`) with only a 5-minute tolerance.
          // `startedAt` here can originate from a bare `DateTime.now()`
          // (local time) — serializing that without `.toUtc()` drops the
          // offset from the ISO string, so Postgres reads it as UTC and every
          // timestamp is off by the device's UTC offset. For any non-UTC
          // timezone that's >5 minutes, so the RPC unconditionally threw
          // "point timestamps outside submitted run window" and no run/
          // territory was ever persisted server-side — reproduced live: every
          // closed-loop run submission failed this way regardless of actual
          // GPS validity.
          'started_at': startedAt.toUtc().toIso8601String(),
          'ended_at': endedAt?.toUtc().toIso8601String(),
          'point_count': pointCount,
          'path': pathGeoJson,
          'point_timestamps': pointTimestampsJson,
          'updated_at': now.toIso8601String(),
        },
      );
    });
  }

  /// Single-row global stat (see `UserStats` table / `WakeUpTaxStore`).
  /// [currentTaxMultiplier] is written to the local cache immediately for a
  /// responsive UI, but is never sent to the server directly — the server
  /// no longer accepts client-written values for this column (P0 fix: it
  /// was previously client-authoritative). Instead [action] ('bump' or
  /// 'reset') tells `SyncWorker` which server-side RPC
  /// (`bump_wake_up_tax`/`reset_wake_up_tax`) to call; the server
  /// recomputes the value itself from whatever it currently has stored, and
  /// `SyncWorker` reconciles the local row with that authoritative result.
  Future<void> upsertUserStats({
    required double currentTaxMultiplier,
    required String action,
  }) {
    final now = DateTime.now();
    return _db.transaction(() async {
      await _db.into(_db.userStats).insertOnConflictUpdate(
            UserStatsCompanion(
              id: const Value(1),
              currentTaxMultiplier: Value(currentTaxMultiplier),
              updatedAt: Value(now),
            ),
          );
      await _enqueue(
        table: 'user_stats',
        entityId: 'current', // no local per-user id; remote upserts key on user_id instead
        operation: OutboxOperation.upsert,
        payload: {'action': action},
      );
    });
  }

  Future<void> _enqueue({
    required String table,
    required String entityId,
    required OutboxOperation operation,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            entityTable: table,
            entityId: entityId,
            operation: operation.name,
            payload: jsonEncode(payload),
            createdAt: now,
            nextAttemptAt: now,
          ),
        );
  }
}
