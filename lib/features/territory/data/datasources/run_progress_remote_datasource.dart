import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real-time backup of the in-progress run to the `active_runs` table —
/// upserted periodically while tracking (mirrors the local `RunCheckpoints`
/// Drift table, see `RunTrackingRepositoryImpl._maybeWriteCheckpoint`).
/// Purely a durability aid, NOT anti-cheat-authoritative: the final
/// territory computation still only ever happens through the `submit_run()`
/// RPC in `SyncWorker._pushRun`. One row per user (`active_runs.user_id` is
/// its primary key) — a device only ever tracks one run at a time, so this
/// keeps the table self-bounding without needing a cleanup job.
@injectable
class RunProgressRemoteDataSource {
  RunProgressRemoteDataSource(this._supabase);

  final SupabaseClient _supabase;

  /// Best-effort by design — every call site swallows failures (same policy
  /// as the local checkpoint write) since this must never interrupt live
  /// tracking or block on network.
  Future<void> upsertProgress({
    required String runId,
    required DateTime startedAt,
    // A decoded GeoJSON object, not an encoded string — `path` is `jsonb`;
    // upserting an already-JSON-encoded string would double-encode it (same
    // pitfall `SyncWorker._pushRun` avoids by `jsonDecode`-ing before
    // calling `submit_run()`).
    required Map<String, Object?> path,
    required List<String> pointTimestamps,
    required double distanceMeters,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('active_runs').upsert({
      'user_id': userId,
      'run_id': runId,
      // `.toUtc()` — same reasoning as `LocalWriter.insertRun`: this is
      // compared against nothing server-side today, but staying consistent
      // avoids baking in another local-time-mislabeled-as-UTC timestamp.
      'started_at': startedAt.toUtc().toIso8601String(),
      'path': path,
      'point_timestamps': pointTimestamps,
      'distance_m': distanceMeters,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> clearProgress() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('active_runs').delete().eq('user_id', userId);
  }
}
