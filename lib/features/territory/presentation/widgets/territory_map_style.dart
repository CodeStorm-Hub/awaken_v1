import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import '../../domain/entities/territory.dart';
import '../../domain/entities/track_point.dart';

/// Minimum ring length (in points) for [TerritoryMapStyle.ringToDashSegments]
/// to bother dashing — anything smaller (near-degenerate slivers) just
/// renders as a single solid segment instead of a barely-visible dash.
const _minDashableRingLength = 4;

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

  /// Breaks a closed ring into alternating "on"/"off" runs of consecutive
  /// points, returning only the "on" runs as separate polylines — used to
  /// fake a dashed outline for rival territory (colorblind-safe secondary
  /// cue, distinguishing it from owned territory's solid outline by more
  /// than hue alone).
  ///
  /// `maplibre_gl`'s `LineOptions` (this plugin version, 0.26.2) has no
  /// `lineDashArray`/dash-pattern property — the only paint knobs it
  /// exposes are color/width/opacity/blur/pattern-image. A real dash
  /// pattern would need either a custom style layer (out of reach of the
  /// annotation-manager API this app's map pages use) or a sprite-based
  /// `linePattern` image asset. Building the dash out of real broken line
  /// segments instead works within the existing `addLine`/`removeLines`
  /// annotation API and needs no new assets — the trade-off is that dash
  /// granularity follows the ring's own vertex spacing (post
  /// `path_simplifier` simplification) rather than a fixed on-screen pixel
  /// length, so very sparse rings dash coarsely.
  static List<List<maplibre.LatLng>> ringToDashSegments(
    List<maplibre.LatLng> ring,
  ) {
    if (ring.length < _minDashableRingLength) return [ring];
    final segments = <List<maplibre.LatLng>>[];
    var i = 0;
    var on = true;
    while (i < ring.length - 1) {
      final end = (i + 2).clamp(0, ring.length - 1);
      if (on) segments.add(ring.sublist(i, end + 1));
      i = end;
      on = !on;
    }
    return segments;
  }
}
