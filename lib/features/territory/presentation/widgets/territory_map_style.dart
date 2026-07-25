import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import '../../domain/entities/territory.dart';
import '../../domain/entities/track_point.dart';

/// Conversion helpers between this app's domain-owned coordinate types
/// (`latlong2`'s `LatLng` in `Territory.rings`, this feature's own
/// `TrackPoint`) and `maplibre_gl`'s own `LatLng` type, which the
/// presentation-layer map widgets (`TerritoryPage`, `ActiveRunPage`) need.
/// Domain/data stay framework-free on purpose (see `GeoBounds`'s doc
/// comment) — this file is where that boundary gets crossed.
abstract final class TerritoryMapStyle {
  static maplibre.LatLng trackPointToLatLng(TrackPoint point) =>
      maplibre.LatLng(point.latitude, point.longitude);

  static List<List<maplibre.LatLng>> territoryRingsToLatLng(
    Territory territory,
  ) {
    return [
      for (final ring in territory.rings)
        [
          for (final point in ring)
            maplibre.LatLng(point.latitude, point.longitude),
        ],
    ];
  }
}
