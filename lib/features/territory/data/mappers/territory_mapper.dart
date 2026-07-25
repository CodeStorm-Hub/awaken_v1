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
      return (ring! as List<Object?>).map((point) {
        final p = point! as List<Object?>;
        return LatLng((p[1]! as num).toDouble(), (p[0]! as num).toDouble());
      }).toList();
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

  /// The lat/lng bounding box enclosing every ring's point — used by the
  /// local territory cache to decide whether a row falls inside a given
  /// viewport query, since the cache stores full geometry but no separate
  /// bbox column.
  static ({double minLat, double minLng, double maxLat, double maxLng})?
  boundsOf(String geoJson) {
    final rings = ringsFromMultiPolygonGeoJson(geoJson);
    double? minLat, minLng, maxLat, maxLng;
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
    if (minLat == null) return null;
    return (minLat: minLat, minLng: minLng!, maxLat: maxLat!, maxLng: maxLng!);
  }
}
