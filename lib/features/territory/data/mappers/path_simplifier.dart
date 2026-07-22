import 'dart:convert';
import 'dart:math' as math;

import '../../domain/entities/track_point.dart';

/// Ramer-Douglas-Peucker simplification + GeoJSON encoding for the path
/// submitted to `submit_run()` (plan §3, step 1 — "RDP simplification for
/// payload size"). Pure Dart, no `turf` dependency: turf's exact point/LatLng
/// API surface isn't worth taking on for an algorithm this small, and the
/// plan already scopes turf to client pre-checks, not path processing.
abstract final class PathSimplifier {
  static List<TrackPoint> simplify(List<TrackPoint> points, {double epsilonMeters = 5}) {
    if (points.length < 3) return points;
    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;
    _rdp(points, 0, points.length - 1, epsilonMeters, keep);
    return [for (var i = 0; i < points.length; i++) if (keep[i]) points[i]];
  }

  static void _rdp(List<TrackPoint> pts, int start, int end, double epsilon, List<bool> keep) {
    if (end <= start + 1) return;
    var maxDist = 0.0;
    var splitIndex = start;
    for (var i = start + 1; i < end; i++) {
      final d = _perpendicularDistanceMeters(pts[i], pts[start], pts[end]);
      if (d > maxDist) {
        maxDist = d;
        splitIndex = i;
      }
    }
    if (maxDist > epsilon) {
      keep[splitIndex] = true;
      _rdp(pts, start, splitIndex, epsilon, keep);
      _rdp(pts, splitIndex, end, epsilon, keep);
    }
  }

  /// Equirectangular projection to local meters centered at [a] — accurate
  /// enough at run-scale (a few km), much cheaper than a full geodesic.
  static double _perpendicularDistanceMeters(TrackPoint p, TrackPoint a, TrackPoint b) {
    const metersPerDegLat = 111320.0;
    final cosLat = math.cos(a.latitude * math.pi / 180);
    double toX(TrackPoint t) => (t.longitude - a.longitude) * metersPerDegLat * cosLat;
    double toY(TrackPoint t) => (t.latitude - a.latitude) * metersPerDegLat;

    final bx = toX(b), by = toY(b);
    final px = toX(p), py = toY(p);
    final lenSq = bx * bx + by * by;
    if (lenSq == 0) return math.sqrt(px * px + py * py);

    final t = ((px * bx) + (py * by)) / lenSq;
    final tc = t.clamp(0.0, 1.0);
    final cx = tc * bx, cy = tc * by;
    final dx = px - cx, dy = py - cy;
    return math.sqrt(dx * dx + dy * dy);
  }

  static String toGeoJsonLineString(List<TrackPoint> points) {
    return jsonEncode({
      'type': 'LineString',
      'coordinates': [for (final p in points) [p.longitude, p.latitude]],
    });
  }
}
