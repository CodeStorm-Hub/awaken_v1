import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/geo_bounds.dart';

/// Territory read-side Supabase access. The `submit_run()` write path is
/// deliberately *not* here — `SyncWorker._pushRun` is the single call site
/// for that RPC (both the online-immediate and offline-retry paths go
/// through the same outbox-driven flow, so there's exactly one place that
/// constructs the request and interprets the response). A duplicate
/// `submitRun()` used to live on this class as a second, drifting
/// implementation that no code ever called — removed rather than kept in
/// sync with two copies of the same anti-cheat-sensitive RPC contract.
@injectable
class TerritoryRemoteDataSource {
  TerritoryRemoteDataSource(this._supabase);

  final SupabaseClient _supabase;

  /// Bbox/viewport spatial query (closes the territory review's flagged
  /// gap) via the `territories_in_bbox` RPC — `ST_MakeEnvelope` + `&&`
  /// against the spatial index, so only territories intersecting the
  /// current map view are pulled, instead of an unbounded most-recent-N scan
  /// that silently misses data once real usage grows past the old flat
  /// limit.
  Future<List<Map<String, Object?>>> fetchTerritoriesInBbox(
    GeoBounds bounds, {
    int limit = 500,
  }) async {
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
