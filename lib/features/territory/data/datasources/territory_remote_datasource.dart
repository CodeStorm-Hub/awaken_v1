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

  /// Server-authoritative total owned area (m²) via `my_owned_area_sqm()` —
  /// sums every non-deleted `territories` row for the caller, unlike the
  /// local Drift cache which is bbox-scoped (see `TerritoryRepositoryImpl`'s
  /// `_cacheCap`/`refreshTerritories` doc comments) and can under-count a
  /// user whose territory spans outside the currently-viewed map area.
  Future<double> fetchMyOwnedAreaSqm() async {
    final result = await _supabase.rpc<Object?>('my_owned_area_sqm');
    return (result! as num).toDouble();
  }

  /// The caller's most recent contested capture (either direction) via the
  /// `current_rival()` RPC — null if there is none yet.
  Future<Map<String, Object?>?> fetchCurrentRival() async {
    final result = await _supabase.rpc<Object?>('current_rival');
    final rows = List<Map<String, Object?>>.from(result! as List);
    return rows.isEmpty ? null : rows.first;
  }

  /// Territories within the decay warning window via `my_territories_at_risk()`.
  Future<List<Map<String, Object?>>> fetchTerritoriesAtRisk() async {
    final result = await _supabase.rpc<Object?>('my_territories_at_risk');
    return List<Map<String, Object?>>.from(result! as List);
  }

  /// Currently-active bounty zones, via the `active_bounty_zones()` RPC
  /// (explicit lat/lng columns rather than relying on ambiguous PostgREST
  /// geography-column serialization — same reasoning as `territories_in_bbox`'s
  /// `geom_geojson`).
  Future<List<Map<String, Object?>>> fetchActiveBountyZones() async {
    final result = await _supabase.rpc<Object?>('active_bounty_zones');
    return List<Map<String, Object?>>.from(result! as List);
  }
}
