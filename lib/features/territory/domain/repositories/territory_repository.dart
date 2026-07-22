import '../entities/territory.dart';

abstract interface class TerritoryRepository {
  /// Locally-cached territories (plan §3 — pull-only cache, never synced
  /// back). Reactive over the local Drift cache, not a live remote stream.
  Stream<List<Territory>> watchTerritories();

  /// Pulls the latest territories from `territories_geojson` (a read view
  /// over PostGIS `geometry`, since PostgREST can't serialize that type
  /// directly) and replaces the local cache.
  Future<void> refreshTerritories();

  /// Total area (m²) of the signed-in user's own territories, from the
  /// local cache — 0 until `refreshTerritories()` has run at least once.
  Stream<double> watchOwnedAreaSqm();
}
