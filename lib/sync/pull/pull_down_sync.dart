import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';

/// One-time reinstall/new-device hydration (plan §6 Phase 6.5) — everything
/// else in `sync/` only pushes local→remote (`LocalWriter`/`SyncWorker`).
/// Writes straight to `AppDatabase`, bypassing `LocalWriter`/the outbox,
/// same reasoning as `TerritoryRepositoryImpl`'s pull-only cache: these
/// rows are already synced, re-enqueuing them for push would be a no-op at
/// best. Only pulls `alarms`/`user_stats` — `sessions`/`runs` history is an
/// operational cache, not something worth restoring verbatim on reinstall.
@lazySingleton
class PullDownSync {
  PullDownSync(this._db, this._supabase);

  final AppDatabase _db;
  final SupabaseClient _supabase;

  /// Call once, after a session is guaranteed (`EnsureAuthSession`). No-ops
  /// if the local `alarms` table is already non-empty — a populated local
  /// DB is never overwritten, which sidesteps any merge/conflict logic.
  Future<void> run() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final hasLocalAlarms = await _db.select(_db.alarms).get().then((rows) => rows.isNotEmpty);
    if (hasLocalAlarms) return;

    final remoteAlarms = await _supabase
        .from('alarms')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    if (remoteAlarms.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _db.alarms,
          remoteAlarms.map((row) {
            return AlarmsCompanion.insert(
              id: row['id']! as String,
              scheduledTime: DateTime.parse(row['scheduled_time']! as String),
              exerciseMode: row['exercise_mode']! as String,
              requiredReps: row['required_reps']! as int,
              penaltyMultiplier: Value((row['penalty_multiplier']! as num).toDouble()),
              isActive: Value(row['is_active']! as bool),
              recurringDays: Value((row['recurring_days'] as String?) ?? ''),
              updatedAt: DateTime.parse(row['updated_at']! as String),
            );
          }).toList(),
        );
      });
    }

    final remoteStats = await _supabase.from('user_stats').select().eq('user_id', userId).maybeSingle();
    if (remoteStats != null) {
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
  }
}
