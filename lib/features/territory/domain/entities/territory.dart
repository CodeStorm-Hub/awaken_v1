import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// A captured territory polygon (plan §3 — server-authoritative, mutated
/// only by `submit_run()`). `rings` is one ring per polygon component of the
/// underlying MultiPolygon (`ST_Difference` can split a territory into
/// disjoint pieces — plan §3 data-model note) — each entry is the outer
/// boundary of one piece; holes are not modeled in v1.
class Territory extends Equatable {
  const Territory({
    required this.id,
    required this.ownerId,
    required this.areaSqm,
    required this.rings,
    required this.isMine,
  });

  final String id;
  final String ownerId;
  final double areaSqm;
  final List<List<LatLng>> rings;
  final bool isMine;

  @override
  List<Object?> get props => [id, ownerId, areaSqm, rings, isMine];
}
