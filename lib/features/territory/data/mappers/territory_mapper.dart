import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../../../sync/local/database.dart';
import '../../domain/entities/territory.dart';

/// GeoJSON MultiPolygon <-> app types. Coordinates are `[lng, lat]` per the
/// GeoJSON spec (opposite order from `LatLng`).
abstract final class TerritoryMapper {
  static Territory fromRow(TerritoryRow row, {required String? currentUserId}) {
    return Territory(
      id: row.id,
      ownerId: row.ownerId,
      areaSqm: row.areaSqm,
      rings: ringsFromMultiPolygonGeoJson(row.geoJson),
      isMine: currentUserId != null && currentUserId == row.ownerId,
    );
  }

  /// Outer ring of each polygon component of a GeoJSON `MultiPolygon`
  /// (`{"type":"MultiPolygon","coordinates":[[[[lng,lat],...]], ...]}`).
  /// Holes (additional rings past the first per polygon) are dropped — v1
  /// doesn't render territory holes (see `Territory.rings` doc).
  static List<List<LatLng>> ringsFromMultiPolygonGeoJson(String geoJson) {
    final decoded = jsonDecode(geoJson) as Map<String, Object?>;
    final type = decoded['type'] as String?;
    final coordinates = decoded['coordinates'] as List<Object?>?;
    if (coordinates == null) return const [];

    List<LatLng> ringToLatLng(Object? ring) {
      return (ring! as List<Object?>)
          .map((point) {
            final p = point! as List<Object?>;
            return LatLng((p[1]! as num).toDouble(), (p[0]! as num).toDouble());
          })
          .toList();
    }

    if (type == 'MultiPolygon') {
      return coordinates.map((polygon) {
        final outerRing = (polygon! as List<Object?>).first;
        return ringToLatLng(outerRing);
      }).toList();
    }
    if (type == 'Polygon') {
      final outerRing = coordinates.first;
      return [ringToLatLng(outerRing)];
    }
    return const [];
  }
}
