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
      polygons: polygonsFromMultiPolygonGeoJson(row.geoJson),
      isMine: currentUserId != null && currentUserId == row.ownerId,
    );
  }

  /// Every ring of every polygon component of a GeoJSON `MultiPolygon`
  /// (`{"type":"MultiPolygon","coordinates":[[[[lng,lat],...], [hole...]], ...]}`)
  /// — index 0 of each component is its outer boundary, any further rings
  /// are interior holes. Previously only the outer ring was kept and holes
  /// were dropped; now the full ring list per component is preserved so the
  /// map layer can render true holes instead of a solid fill.
  static List<List<List<LatLng>>> polygonsFromMultiPolygonGeoJson(
    String geoJson,
  ) {
    final decoded = jsonDecode(geoJson) as Map<String, Object?>;
    final type = decoded['type'] as String?;
    final coordinates = decoded['coordinates'] as List<Object?>?;
    if (coordinates == null) return const [];

    List<LatLng> ringToLatLng(Object? ring) {
      return (ring! as List<Object?>).map((point) {
        final p = point! as List<Object?>;
        return LatLng((p[1]! as num).toDouble(), (p[0]! as num).toDouble());
      }).toList();
    }

    List<List<LatLng>> polygonToRings(Object? polygon) {
      return (polygon! as List<Object?>).map(ringToLatLng).toList();
    }

    if (type == 'MultiPolygon') {
      return coordinates.map(polygonToRings).toList();
    }
    if (type == 'Polygon') {
      return [polygonToRings(coordinates)];
    }
    return const [];
  }

  /// The lat/lng bounding box enclosing every ring's point — used by the
  /// local territory cache to decide whether a row falls inside a given
  /// viewport query, since the cache stores full geometry but no separate
  /// bbox column.
  static ({double minLat, double minLng, double maxLat, double maxLng})?
  boundsOf(String geoJson) {
    final polygons = polygonsFromMultiPolygonGeoJson(geoJson);
    double? minLat, minLng, maxLat, maxLng;
    for (final rings in polygons) {
      for (final ring in rings) {
        for (final point in ring) {
          minLat = minLat == null
              ? point.latitude
              : (point.latitude < minLat ? point.latitude : minLat);
          maxLat = maxLat == null
              ? point.latitude
              : (point.latitude > maxLat ? point.latitude : maxLat);
          minLng = minLng == null
              ? point.longitude
              : (point.longitude < minLng ? point.longitude : minLng);
          maxLng = maxLng == null
              ? point.longitude
              : (point.longitude > maxLng ? point.longitude : maxLng);
        }
      }
    }
    if (minLat == null) return null;
    return (minLat: minLat, minLng: minLng!, maxLat: maxLat!, maxLng: maxLng!);
  }
}
