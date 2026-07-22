import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/geo_bounds.dart';

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

  /// Bbox/viewport spatial query (closes the territory review's flagged
  /// gap) via the `territories_in_bbox` RPC — `ST_MakeEnvelope` + `&&`
  /// against the spatial index, so only territories intersecting the
  /// current map view are pulled, instead of an unbounded most-recent-N scan
  /// that silently misses data once real usage grows past the old flat
  /// limit.
  Future<List<Map<String, Object?>>> fetchTerritoriesInBbox(GeoBounds bounds, {int limit = 500}) async {
    final result = await _supabase.rpc<Object?>(
      'territories_in_bbox',
      params: {
        'min_lng': bounds.minLng,
        'min_lat': bounds.minLat,
        'max_lng': bounds.maxLng,
        'max_lat': bounds.maxLat,
        'row_limit': limit,
      },
    );
    return List<Map<String, Object?>>.from(result! as List);
  }
}
