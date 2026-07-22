import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the server-authoritative `submit_run()` RPC (plan §3) directly —
/// this is the one deliberate exception to "features never touch Supabase
/// directly" (plan §3 amendment): `submit_run` is a compute call, not a
/// table write, and its jsonb `path` parameter needs the raw GeoJSON decoded
/// into a value the supabase-dart client can serialize, which a generic
/// outbox table-upsert can't express (see `SyncWorker._pushRun`, which
/// reuses this same call for the offline-retry path).
@injectable
class TerritoryRemoteDataSource {
  TerritoryRemoteDataSource(this._supabase);

  final SupabaseClient _supabase;

  Future<Map<String, Object?>> submitRun({
    required String runId,
    required String pathGeoJson,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final result = await _supabase.rpc<Object?>(
      'submit_run',
      params: {
        'p_run_id': runId,
        'p_path': jsonDecode(pathGeoJson),
        'p_started_at': startedAt.toIso8601String(),
        'p_ended_at': endedAt.toIso8601String(),
      },
    );
    return Map<String, Object?>.from(result! as Map);
  }

  /// Reads `territories_geojson` (plan §5c) — a view over the PostGIS
  /// `territories.geom` column, since PostgREST can't serialize `geometry`
  /// directly. No true bbox filter yet (would need a dedicated RPC); v1
  /// caps by most-recently-updated, which is adequate for the single-map
  /// use case at current data volumes.
  Future<List<Map<String, Object?>>> fetchTerritories({int limit = 200}) async {
    final rows = await _supabase
        .from('territories_geojson')
        .select()
        .order('updated_at', ascending: false)
        .limit(limit);
    return List<Map<String, Object?>>.from(rows as List);
  }
}
