import '../entities/bounty_zone.dart';
import '../entities/geo_bounds.dart';
import '../entities/rival.dart';
import '../entities/territory.dart';
import '../entities/territory_at_risk.dart';

abstract interface class TerritoryRepository {
  /// Locally-cached territories (plan §3 — pull-only cache, never synced
  /// back). Reactive over the local Drift cache, not a live remote stream.
  Stream<List<Territory>> watchTerritories();

  /// Pulls territories intersecting [bounds] via the `territories_in_bbox`
  /// RPC (closes the territory review's flagged bbox-query gap — no longer
  /// an unbounded most-recent-N scan) and merges them into the local cache.
  Future<void> refreshTerritories(GeoBounds bounds);

  /// Total area (m²) of the signed-in user's own territories, from the
  /// local cache — 0 until `refreshTerritories()` has run at least once.
  Stream<double> watchOwnedAreaSqm();

  /// The caller's most recent contested capture, either direction — null
  /// if there is none yet. Not cached locally (a one-shot fetch, refreshed
  /// whenever `TerritoryPage` re-reads it).
  Future<Rival?> fetchCurrentRival();

  /// Territories within the decay warning window.
  Future<List<TerritoryAtRisk>> fetchTerritoriesAtRisk();

  /// Currently-active bounty zones.
  Future<List<BountyZone>> fetchActiveBountyZones();
}
