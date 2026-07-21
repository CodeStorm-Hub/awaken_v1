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
              updatedAt: now,
            ),
          );
      await _enqueue(
        table: 'runs',
        entityId: id,
        operation: OutboxOperation.upsert,
        payload: {
          'id': id,
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt?.toIso8601String(),
          'point_count': pointCount,
          'path': pathGeoJson,
          'updated_at': now.toIso8601String(),
        },
      );
    });
  }

  /// Single-row global stat (see `UserStats` table / `WakeUpTaxStore`).
  /// The remote `user_stats` row is keyed by `user_id`, which `SyncWorker`
  /// stamps onto every push — this class never needs to know the current
  /// user's id.
  Future<void> upsertUserStats({required double currentTaxMultiplier}) {
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
        payload: {
          'current_tax_multiplier': currentTaxMultiplier,
          'updated_at': now.toIso8601String(),
        },
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
