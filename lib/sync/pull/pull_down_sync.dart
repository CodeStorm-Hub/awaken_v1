import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';

/// Incremental delta pull (plan §6 Phase 6.5, hardened per Phase 2 review):
/// everything else in `sync/` only pushes local→remote (`LocalWriter`/
/// `SyncWorker`) — this is the only remote→local direction. Runs repeatedly
/// (bootstrap, and every `SyncWorker` drain cycle), not just once on a bare
/// local cache: the previous design early-returned forever once `alarms`
/// had any local rows at all, so a second device's edits (or a server-side
/// admin change) never converged back down after the very first pull. Each
/// covered table tracks its own `updated_at` watermark in `SyncMeta` and
/// pulls only rows newer than it, including soft-delete tombstones.
///
/// Only `alarms`/`user_stats`/`sessions` are covered — `runs`/`territories`
/// are deliberately excluded: `runs.path` is PostGIS geometry needing
/// `ST_AsGeoJSON` handling this table doesn't have, and `territories` has
/// its own bbox-scoped pull path (`TerritoryRepositoryImpl.refreshTerritories`)
/// that a global delta pull would duplicate and fight over.
@lazySingleton
class PullDownSync {
  PullDownSync(this._db, this._supabase);

  final AppDatabase _db;
  final SupabaseClient _supabase;

  /// Call from bootstrap (after `EnsureAuthSession`) and periodically
  /// thereafter (`SyncWorker` calls this once per drain cycle) — cheap and
  /// safe to call repeatedly; each covered table only fetches rows newer
  /// than its own watermark.
  Future<void> run() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _pullAlarms(userId);
    await _pullUserStats(userId);
    await _pullSessions(userId);
  }

  Future<DateTime?> _watermark(String table) async {
    final row = await (_db.select(_db.syncMeta)..where((t) => t.entityTable.equals(table))).getSingleOrNull();
    return row?.lastPulledAt;
  }

  Future<void> _saveWatermark(String table, DateTime at) {
    return _db
        .into(_db.syncMeta)
        .insertOnConflictUpdate(SyncMetaCompanion.insert(entityTable: table, lastPulledAt: at));
  }

  /// The newest `updated_at` among [rows] (already-parsed `DateTime`s), or
  /// [fallback] (the pull's start time) if [rows] is empty — advances the
  /// watermark even on a quiet pull, since "no rows newer than X" still
  /// means X is a safe new low-water mark.
  DateTime _maxUpdatedAt(Iterable<DateTime> rows, DateTime fallback) {
    var max = fallback;
    for (final at in rows) {
      if (at.isAfter(max)) max = at;
    }
    return max;
  }

  Future<void> _pullAlarms(String userId) async {
    const table = 'alarms';
    final since = await _watermark(table);
    final pullStartedAt = DateTime.now();

    var query = _supabase.from(table).select().eq('user_id', userId);
    if (since != null) query = query.gt('updated_at', since.toIso8601String());
    final remoteRows = await query;
    if (remoteRows.isEmpty) {
      await _saveWatermark(table, pullStartedAt);
      return;
    }

    await _db.transaction(() async {
      for (final row in remoteRows) {
        final remoteUpdatedAt = DateTime.parse(row['updated_at']! as String);
        final id = row['id']! as String;
        final local = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).getSingleOrNull();
        // Last-writer-wins by `updated_at`: a local row newer than what the
        // server just returned means a not-yet-pushed local edit is still
        // sitting in the outbox — applying the older remote value would
        // clobber it right before the outbox pushes it anyway.
        if (local != null && !remoteUpdatedAt.isAfter(local.updatedAt)) continue;

        if (row['deleted_at'] != null) {
          await (_db.delete(_db.alarms)..where((t) => t.id.equals(id))).go();
          continue;
        }
        await _db.into(_db.alarms).insertOnConflictUpdate(
              AlarmsCompanion.insert(
                id: id,
                scheduledTime: DateTime.parse(row['scheduled_time']! as String),
                exerciseMode: row['exercise_mode']! as String,
                requiredReps: row['required_reps']! as int,
                penaltyMultiplier: Value((row['penalty_multiplier']! as num).toDouble()),
                isActive: Value(row['is_active']! as bool),
                recurringDays: Value((row['recurring_days'] as String?) ?? ''),
                updatedAt: remoteUpdatedAt,
              ),
            );
      }
    });

    await _saveWatermark(
      table,
      _maxUpdatedAt(remoteRows.map((r) => DateTime.parse(r['updated_at']! as String)), pullStartedAt),
    );
  }

  Future<void> _pullUserStats(String userId) async {
    final remoteStats = await _supabase.from('user_stats').select().eq('user_id', userId).maybeSingle();
    if (remoteStats == null) return;
    await _db
        .into(_db.userStats)
        .insertOnConflictUpdate(
          UserStatsCompanion(
            id: const Value(1),
            currentTaxMultiplier: Value((remoteStats['current_tax_multiplier']! as num).toDouble()),
            updatedAt: Value(DateTime.parse(remoteStats['updated_at']! as String)),
          ),
        );
  }

  Future<void> _pullSessions(String userId) async {
    const table = 'sessions';
    final since = await _watermark(table);
    final pullStartedAt = DateTime.now();

    var query = _supabase.from(table).select().eq('user_id', userId);
    if (since != null) query = query.gt('updated_at', since.toIso8601String());
    final remoteRows = await query;
    if (remoteRows.isEmpty) {
      await _saveWatermark(table, pullStartedAt);
      return;
    }

    await _db.transaction(() async {
      for (final row in remoteRows) {
        final remoteUpdatedAt = DateTime.parse(row['updated_at']! as String);
        final id = row['id']! as String;
        final local = await (_db.select(_db.sessions)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && !remoteUpdatedAt.isAfter(local.updatedAt)) continue;

        if (row['deleted_at'] != null) {
          await (_db.delete(_db.sessions)..where((t) => t.id.equals(id))).go();
          continue;
        }
        final completedAt = row['completed_at'] as String?;
        await _db.into(_db.sessions).insertOnConflictUpdate(
              SessionsCompanion.insert(
                id: id,
                alarmId: Value(row['alarm_id'] as String?),
                exerciseMode: row['exercise_mode']! as String,
                repsCompleted: row['reps_completed']! as int,
                startedAt: DateTime.parse(row['started_at']! as String),
                completedAt: Value(completedAt == null ? null : DateTime.parse(completedAt)),
                updatedAt: remoteUpdatedAt,
              ),
            );
      }
    });

    await _saveWatermark(
      table,
      _maxUpdatedAt(remoteRows.map((r) => DateTime.parse(r['updated_at']! as String)), pullStartedAt),
    );
  }
}
