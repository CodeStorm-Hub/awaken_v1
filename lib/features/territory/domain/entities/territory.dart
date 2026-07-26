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
  });

  final String id;
  final String ownerId;
  final double areaSqm;
  final List<List<List<LatLng>>> polygons;
  final bool isMine;

  @override
  List<Object?> get props => [id, ownerId, areaSqm, polygons, isMine];
}
