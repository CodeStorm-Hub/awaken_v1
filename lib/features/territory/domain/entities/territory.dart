import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// A captured territory polygon (plan §3 — server-authoritative, mutated
/// only by `submit_run()`). `polygons` is one entry per polygon component of
/// the underlying MultiPolygon (`ST_Difference` can split a territory into
/// disjoint pieces — plan §3 data-model note); each component is itself a
/// list of rings — index 0 is the outer boundary, any further rings are
/// interior holes (e.g. a rival's `ST_Difference` cutout that landed fully
/// inside this territory rather than at its edge).
class Territory extends Equatable {
  const Territory({
    required this.id,
    required this.ownerId,
    required this.areaSqm,
    required this.polygons,
    required this.isMine,
    this.health,
  });

  final String id;
  final String ownerId;
  final double areaSqm;
  final List<List<List<LatLng>>> polygons;
  final bool isMine;

  /// Server-computed decay health (0-100), from `territories_in_bbox()`'s
  /// `health` column. Nullable since older cached/local rows fetched before
  /// this column existed won't have it — callers should fall back to the
  /// client-side at-risk-window approximation when null (see
  /// `TerritoryPage._healthOf`).
  final int? health;

  @override
  List<Object?> get props => [id, ownerId, areaSqm, polygons, isMine, health];
}
