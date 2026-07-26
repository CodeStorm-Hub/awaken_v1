import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import '../../domain/entities/territory.dart';
import '../../domain/entities/track_point.dart';

/// Conversion helpers between this app's domain-owned coordinate types
/// (`latlong2`'s `LatLng` in `Territory.polygons`, this feature's own
/// `TrackPoint`) and `maplibre_gl`'s own `LatLng` type, which the
/// presentation-layer map widgets (`TerritoryPage`, `ActiveRunPage`) need.
/// Domain/data stay framework-free on purpose (see `GeoBounds`'s doc
/// comment) — this file is where that boundary gets crossed.
abstract final class TerritoryMapStyle {
  static maplibre.LatLng trackPointToLatLng(TrackPoint point) =>
      maplibre.LatLng(point.latitude, point.longitude);

  /// One entry per polygon component, each itself the full ring list
  /// (outer + any holes) `maplibre_gl`'s `FillOptions.geometry` expects for
  /// a single fill to render holes as literal holes rather than a second
  /// opaque fill on top.
  static List<List<List<maplibre.LatLng>>> territoryPolygonsToLatLng(
    Territory territory,
  ) {
    return [
      for (final rings in territory.polygons)
        [
          for (final ring in rings)
            [
              for (final point in ring)
                maplibre.LatLng(point.latitude, point.longitude),
            ],
        ],
    ];
  }
}
