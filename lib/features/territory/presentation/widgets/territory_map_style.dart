import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import '../../domain/entities/territory.dart';
import '../../domain/entities/track_point.dart';

/// Conversion helpers between this app's domain-owned coordinate types
/// (`latlong2`'s `LatLng` in `Territory.polygons`, this feature's own
/// `TrackPoint`) and either `maplibre_gl`'s own `LatLng` type or raw GeoJSON,
/// which the presentation-layer map widgets (`TerritoryPage`, `ActiveRunPage`)
/// need. Domain/data stay framework-free on purpose (see `GeoBounds`'s doc
/// comment) — this file is where that boundary gets crossed.
abstract final class TerritoryMapStyle {
  static maplibre.LatLng trackPointToLatLng(TrackPoint point) =>
      maplibre.LatLng(point.latitude, point.longitude);

  /// Builds a GeoJSON `Feature` (RFC 7946) for one [territory], to be placed
  /// into a `FeatureCollection` fed to `addGeoJsonSource`/`setGeoJsonSource`.
  /// [properties] carries whatever the map's paint-property expressions need
  /// to distinguish owned/rival/at-risk territory (see `TerritoryPage`'s
  /// `_territoryFeatureProperties`) — merged in verbatim, alongside an `id`
  /// property every consumer's `["get", "id"]` expressions rely on.
  ///
  /// `Territory.polygons` is one entry per disjoint polygon component (an
  /// `ST_Difference` can split a territory into separate pieces — see
  /// `Territory`'s own doc comment), each itself a list of rings (index 0
  /// outer boundary, further entries interior holes). That's exactly a
  /// GeoJSON `MultiPolygon`'s `coordinates` shape once each `LatLng` is
  /// flipped to GeoJSON's `[lng, lat]` order and each ring is explicitly
  /// closed (first position repeated as the last) — GeoJSON requires closed
  /// rings; the domain type doesn't guarantee it, so this always appends the
  /// closing point rather than checking equality first (a harmless
  /// zero-length extra segment if the ring was already closed).
  static Map<String, dynamic> territoryToGeoJsonFeature(
    Territory territory,
    Map<String, dynamic> properties,
  ) {
    // A ring needs >= 3 distinct points to be a valid GeoJSON LinearRing
    // once closed (4 positions minimum, including the repeated closing
    // point). The previous version emitted an empty `[]` placeholder for
    // an empty ring instead of dropping it, handing the native renderer a
    // polygon component with a degenerate ring — the confirmed cause of
    // "Invalid geometry in line layer" warnings seen in live logcat output
    // (flutter_run_logs.md), since the outline LineLayer reads this same
    // source. Filtering here (both the ring and, if every ring in a
    // component was degenerate, the whole component) keeps only valid
    // geometry reaching `addGeoJsonSource`/`setGeoJsonSource`.
    final coordinates = [
      for (final rings in territory.polygons)
        if (rings.any((ring) => ring.length >= 3))
          [
            for (final ring in rings)
              if (ring.length >= 3)
                [
                  for (final point in ring) [point.longitude, point.latitude],
                  [ring.first.longitude, ring.first.latitude],
                ],
          ],
    ];
    return {
      'type': 'Feature',
      'properties': {'id': territory.id, ...properties},
      'geometry': {'type': 'MultiPolygon', 'coordinates': coordinates},
    };
  }

  /// Builds a hollow "wall" GeoJSON `Feature` for one [territory] — a thin
  /// frame tracing just the *border* of each polygon component (outer ring
  /// minus an inward-offset copy of itself, expressed as a hole), rather
  /// than the solid fill `territoryToGeoJsonFeature` builds. Used only by
  /// the 3D fill-extrusion "wall" layer: a solid extruded block over the
  /// *entire* captured area was found (live device review) to both look
  /// like a huge plain slab and to completely occlude the streets/buildings
  /// underneath, defeating the point of rendering them in §5.1. A wall
  /// along just the perimeter reads as "this ground is claimed" without
  /// hiding what's inside it.
  ///
  /// Simplification: only each component's *outer* ring gets a wall — any
  /// interior holes already in `Territory.polygons` (an `ST_Difference`
  /// rival cutout landing fully inside this territory, per that field's own
  /// doc comment) are not separately walled off. That's a rare shape rather
  /// than the common case, and a wall around the outer boundary only is a
  /// reasonable simplification for a decorative marker rather than the
  /// authoritative capture geometry (which the flat fill/outline layers
  /// still render correctly from the untouched polygon data).
  static Map<String, dynamic> territoryToWallGeoJsonFeature(
    Territory territory,
    Map<String, dynamic> properties, {
    double wallThicknessMeters = 6,
  }) {
    final polygons = <List<List<List<double>>>>[];
    for (final rings in territory.polygons) {
      if (rings.isEmpty) continue;
      final outer = rings.first;
      if (outer.length < 3) continue;
      final inset = _insetRing(outer, wallThicknessMeters);
      if (inset == null) continue;
      final outerClosed = [
        for (final p in outer) [p.longitude, p.latitude],
        [outer.first.longitude, outer.first.latitude],
      ];
      final insetClosed = [
        for (final p in inset) [p.longitude, p.latitude],
        [inset.first.longitude, inset.first.latitude],
      ];
      polygons.add([outerClosed, insetClosed]);
    }
    return {
      'type': 'Feature',
      'properties': {'id': territory.id, ...properties},
      'geometry': {'type': 'MultiPolygon', 'coordinates': polygons},
    };
  }

  /// Inward-offsets a polygon ring by [thicknessMeters] using the standard
  /// per-vertex averaged-edge-normal ("miter") method — projects to a local
  /// flat equirectangular approximation centered on the ring (accurate
  /// enough at the scale of a running-loop capture, same approximation
  /// `_circlePolygon`-style helpers elsewhere in this feature already make),
  /// offsets there, then projects back. Not a robust general polygon-offset
  /// implementation (no self-intersection repair for sharp concave
  /// corners), but sufficient for a decorative wall on the roughly convex,
  /// gently-concave loop shapes real captures produce. Returns `null` if the
  /// ring is degenerate. Auto-shrinks the requested thickness for small
  /// captures (proportional to the ring's own equivalent radius) so a tiny
  /// capture's wall doesn't turn the ring inside-out.
  static List<ll.LatLng>? _insetRing(
    List<ll.LatLng> ring,
    double thicknessMeters,
  ) {
    final pts = List<ll.LatLng>.from(ring);
    if (pts.length > 1 &&
        pts.first.latitude == pts.last.latitude &&
        pts.first.longitude == pts.last.longitude) {
      pts.removeLast();
    }
    final n = pts.length;
    if (n < 3) return null;

    final centerLat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / n;
    const metersPerDegLat = 111320.0;
    final metersPerDegLng =
        metersPerDegLat * math.cos(centerLat * math.pi / 180);
    if (metersPerDegLng.abs() < 1e-9) return null;

    final xy = pts
        .map(
          (p) => ui.Offset(
            p.longitude * metersPerDegLng,
            p.latitude * metersPerDegLat,
          ),
        )
        .toList();

    // Auto-scale the wall thickness against the ring's own size so a small
    // capture (equivalent radius well under the requested thickness) still
    // gets a valid, non-self-intersecting inset.
    var minX = xy.first.dx, maxX = xy.first.dx;
    var minY = xy.first.dy, maxY = xy.first.dy;
    for (final p in xy) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final halfExtent = math.min(maxX - minX, maxY - minY) / 2;
    final effectiveThickness = math.min(thicknessMeters, halfExtent * 0.35);
    if (effectiveThickness <= 0.5) return null;

    double signedArea = 0;
    for (var i = 0; i < n; i++) {
      final a = xy[i];
      final b = xy[(i + 1) % n];
      signedArea += (a.dx * b.dy - b.dx * a.dy);
    }
    final isCCW = signedArea > 0;

    ui.Offset unitNormalOf(ui.Offset edge) {
      final len = edge.distance;
      if (len < 1e-9) return ui.Offset.zero;
      return ui.Offset(-edge.dy / len, edge.dx / len);
    }

    final result = <ll.LatLng>[];
    for (var i = 0; i < n; i++) {
      final prev = xy[(i - 1 + n) % n];
      final curr = xy[i];
      final next = xy[(i + 1) % n];
      var n1 = unitNormalOf(curr - prev);
      var n2 = unitNormalOf(next - curr);
      if (!isCCW) {
        n1 = -n1;
        n2 = -n2;
      }
      var avg = n1 + n2;
      final avgLen = avg.distance;
      avg = avgLen < 1e-6 ? n1 : avg / avgLen;
      final cosHalf = (n1.dx * avg.dx + n1.dy * avg.dy).clamp(0.2, 1.0);
      final miter = (effectiveThickness / cosHalf).clamp(
        0.0,
        effectiveThickness * 2.5,
      );
      final offsetPt = curr + avg * miter;
      result.add(
        ll.LatLng(offsetPt.dy / metersPerDegLat, offsetPt.dx / metersPerDegLng),
      );
    }
    return result;
  }

  /// A cheap centroid approximation — the plain average of the *outer* ring
  /// (index 0) of the *first* polygon component. Not a true area-weighted
  /// polygon centroid (would misplace it for a concave/L-shaped capture, or
  /// one `ST_Difference` has split unevenly across components), but good
  /// enough to plant a flag marker (§"Conquest Skyline" redesign) roughly
  /// inside the territory's largest piece without pulling in a full
  /// computational-geometry dependency for a decorative marker position.
  static maplibre.LatLng territoryCentroid(Territory territory) {
    for (final rings in territory.polygons) {
      if (rings.isEmpty || rings.first.isEmpty) continue;
      final outer = rings.first;
      var lat = 0.0, lng = 0.0;
      for (final point in outer) {
        lat += point.latitude;
        lng += point.longitude;
      }
      return maplibre.LatLng(lat / outer.length, lng / outer.length);
    }
    return const maplibre.LatLng(0, 0);
  }

  /// Same cheap per-outer-ring average [territoryCentroid] uses, but one per
  /// polygon *component* rather than just the first. Territories routinely
  /// have multiple disjoint components now that `submit_run()` merges a
  /// newly-closed loop into an existing territory whenever it's within 75m
  /// (not just touching/overlapping) — each disjoint block is a real piece
  /// of the empire the player can see on the ground, so each gets its own
  /// flag (`_redrawFlags`) rather than only the first component.
  static List<maplibre.LatLng> territoryComponentCentroids(
    Territory territory,
  ) {
    final centroids = <maplibre.LatLng>[];
    for (final rings in territory.polygons) {
      if (rings.isEmpty || rings.first.isEmpty) continue;
      final outer = rings.first;
      var lat = 0.0, lng = 0.0;
      for (final point in outer) {
        lat += point.latitude;
        lng += point.longitude;
      }
      centroids.add(maplibre.LatLng(lat / outer.length, lng / outer.length));
    }
    return centroids;
  }

  /// Style-layer image name registered via [generateFlagIconBytes] +
  /// `controller.addImage(flagIconName, bytes, sdf: true)`. `sdf: true`
  /// lets the icon be tinted per-feature via a `SymbolLayerProperties.
  /// iconColor` data expression (e.g. `['get', 'extrusionColor']`) instead
  /// of baking one fixed color into the PNG — one texture serves every
  /// ownership tier (mine/squadmate/rival).
  static const flagIconName = 'awaken-territory-flag';

  /// Renders a small pennant-on-a-pole flag glyph via `dart:ui` (a plain
  /// white shape on a transparent background) rather than bundling a binary
  /// asset — this is the *only* piece of map styling in this feature that
  /// needs an actual image (every other visual is a paint-property
  /// expression on vector geometry), and a runtime-rendered glyph avoids
  /// adding a new asset file + `pubspec.yaml` entry for one small icon.
  static Future<Uint8List> generateFlagIconBytes({int size = 64}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final s = size.toDouble();
    // Pole.
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(s * 0.44, s * 0.06, s * 0.09, s * 0.88),
        ui.Radius.circular(s * 0.03),
      ),
      paint,
    );
    // Pennant.
    final pennant = ui.Path()
      ..moveTo(s * 0.50, s * 0.10)
      ..lineTo(s * 0.94, s * 0.30)
      ..lineTo(s * 0.50, s * 0.50)
      ..close();
    canvas.drawPath(pennant, paint);
    // Base.
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(s * 0.485, s * 0.94),
        width: s * 0.26,
        height: s * 0.09,
      ),
      paint,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Style-layer image name for the "current position" marker (§ replaces
  /// the old flat `Circle` annotation both `TerritoryPage`/`ActiveRunPage`
  /// used). Not `sdf: true` like [flagIconName] — this bakes in its own
  /// shading/highlight/shadow, so it's registered once per [color] via
  /// [generateAvatarPuckIconBytes] rather than tinted per-feature.
  static const avatarPuckIconNamePrefix = 'awaken-avatar-puck';

  /// Renders a small "3D puck" location marker via `dart:ui` — a soft
  /// ground shadow, a white contrast halo, a shaded sphere in [color] with a
  /// specular highlight, and a darker crescent along the bottom edge to fake
  /// a lit 3D volume. MapLibre has no true 3D-model/billboard support (same
  /// constraint the plan's §5.5 atmosphere spike already found for sky/
  /// terrain), so this is the same trick [generateFlagIconBytes] uses: a
  /// flat baked PNG that *reads* as dimensional rather than an actual mesh.
  static Future<Uint8List> generateAvatarPuckIconBytes({
    ui.Color color = const ui.Color(0xFF00E5FF),
    int size = 192,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final s = size.toDouble();
    final center = ui.Offset(s / 2, s / 2);
    final radius = s * 0.28;

    // 1. Outer Glowing Pulsing Aura (Cyan Glow)
    final auraPaint = ui.Paint()
      ..color = const ui.Color(0x6600E5FF)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14);
    canvas.drawCircle(center, radius * 1.55, auraPaint);

    // 2. Soft Drop Shadow
    final shadowPaint = ui.Paint()
      ..color = const ui.Color(0xAA000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawCircle(
      center + const ui.Offset(0, 4),
      radius * 1.25,
      shadowPaint,
    );

    // 3. Thick Pure-White Contrast Outer Ring
    canvas.drawCircle(
      center,
      radius * 1.22,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    // 4. Vibrant Electric Cyan Primary Puck Body
    canvas.drawCircle(center, radius, ui.Paint()..color = color);

    // 5. Lit Sphere Bottom Shading Crescent
    canvas.drawArc(
      ui.Rect.fromCircle(center: center, radius: radius * 0.85),
      0.1 * math.pi,
      0.9 * math.pi,
      false,
      ui.Paint()
        ..color = const ui.Color(0x44000000)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = radius * 0.4
        ..strokeCap = ui.StrokeCap.round,
    );

    // 6. Bright 3D Specular Gem Highlight (Upper-Left)
    canvas.drawCircle(
      ui.Offset(center.dx - radius * 0.35, center.dy - radius * 0.35),
      radius * 0.38,
      ui.Paint()..color = const ui.Color(0xEEFFFFFF),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Great-circle distance in meters — used by `buildTerritoryGeoJsonPayload`
  /// and `TerritoryPage` for front-line proximity checks.
  static double haversineMeters(maplibre.LatLng a, maplibre.LatLng b) {
    const earthRadiusM = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h));
  }
}

/// Pokémon-GO-inspired basemap recolor, applied on top of whichever
/// OpenFreeMap style tier `MapStyleLoader` resolved (redesign item, not part
/// of the original territory-feature plan).
///
/// Mechanism: `MapLibreMap.styleString` *does* accept a raw style JSON
/// string, not just a URL (`maplibre_map.dart`'s own doc comment lists it as
/// option 4) — so fetching OpenFreeMap's style once, patching it
/// client-side, and passing the patched JSON as `styleString` was the first
/// design considered. It was rejected: `styleString` is read exactly once,
/// at native-view creation (`creationParams` in `maplibre_map.dart`), and
/// `MapStyleLoader` already depends on that exact constraint — it's *why*
/// changing style requires bumping `styleKey` to tear down and rebuild the
/// native view (see its own doc comment). Fetching+patching is unavoidably
/// async, so feeding a patched JSON into `styleString` would mean either (a)
/// gating the very first `MapLibreMap` build behind a network fetch — a
/// widget-lifecycle change this task shouldn't need, and one that risks the
/// load-timing behavior `MapStyleLoader`'s fallback tiers are hardened
/// around — or (b) building with the unrecolored URL first and bumping
/// `styleKey` again once the patched JSON lands, causing a visible
/// double-load flash on every style (re)load. Neither is worth it here.
///
/// Instead this applies the recolor via `setLayerProperties` from
/// `onStyleLoadedCallback`, once per style load — the same hook
/// `TerritoryPage`/`ActiveRunPage` already use to resync territories/route
/// after a style swap, including a fallback-tier swap (which tears down and
/// recreates the native view and re-fires `onStyleLoaded`). Layer ids are
/// matched against `controller.getLayerIds()` before patching (never
/// assumed present) — OpenFreeMap's `liberty` (light) and `dark` styles
/// turned out, on inspection, to use two genuinely different OpenMapTiles
/// layer sets (e.g. light has a dedicated `park`/`park_outline` pair and
/// per-rank `poi_r*` layers; dark folds parks into `landuse_park` and
/// renders no POI layer at all) — so this keys off two separate known id
/// lists rather than one generic source-layer rule that can't reliably tell
/// "wood/grass" landcover apart from "ice/sand" landcover on id alone. An id
/// absent from the active style (notably the bundled offline fallback tier —
/// a different, low-zoom extract) is simply skipped — the map degrades
/// gracefully to the unrecolored style there, matching this being the
/// lowest-priority tier.
abstract final class TerritoryBasemapRecolor {
  // Palette (design brief) — bright saturated water/greens against a
  // desaturated-teal road network with white casings/labels, Pokémon-GO
  // style. Kept as named constants rather than inlined so the light/dark id
  // maps below read as "what gets this color," not repeated hex literals.
  static const _waterMain = '#2594E4';
  static const _waterShallow = '#5ABBEC'; // rivers/streams (linear water)
  static const _landcoverGreen = '#46EBA7'; // parks, wood/grass landcover
  static const _landuseGreen =
      '#82FD88'; // man-made green landuse (residential)
  static const _roadTeal = '#4DA39A';
  static const _roadHalo = '#FFFFFF';
  static const _roadLabelColor = '#FFFFFF';
  // No halo-color was set on the road-name layers in either source style
  // (style-spec default is fully transparent) — without one, white labels
  // would disappear entirely over light basemap areas. A translucent dark
  // halo restores legibility in both themes without needing per-theme
  // values.
  static const _roadLabelHalo = 'rgba(0,0,0,0.55)';
  static const _boundaryColor = '#E4E1E1';
  // Both `styles/liberty` and `styles/dark` declare every text layer's
  // `text-font` as `['Noto Sans Regular']` (confirmed by fetching both
  // style documents directly) — OpenFreeMap only hosts Noto Sans glyphs.
  // `SymbolLayerProperties.textFont`'s own doc comment records its SDK
  // default as `[Open Sans Regular, Arial Unicode MS Regular]`, and
  // `setLayerProperties` serializes with `skipNulls: false` (confirmed via
  // package source), so any `SymbolLayerProperties(...)` call below that
  // left `textFont` unset was sending an explicit `text-font: null`,  which
  // the native side was applying as that Open-Sans SDK default instead of
  // leaving Noto Sans alone — the confirmed cause of the
  // "Failed to load glyph range ... HTTP 404" errors in live logcat output
  // (flutter_run_logs.md): OpenFreeMap doesn't host Open Sans at all.
  // Every `SymbolLayerProperties` construction below must repeat this.
  static const _notoSansRegular = ['Noto Sans Regular'];
  // The brief's POI treatment ("pale mint fill #CAFFD2 with white stroke")
  // describes a filled shape, but OpenFreeMap's POI layers are `symbol`
  // layers (icon + text label), not fills — there's no POI polygon to fill.
  // Translated to the nearest symbol-layer equivalent: a readable dark-mint
  // label color (literal pale mint text would be near-invisible on a light
  // basemap) with a white halo, rather than hiding POI labels outright.
  static const _poiTextColor = '#0E9C55';
  static const _poiHalo = '#FFFFFF';

  /// OpenFreeMap `styles/liberty` (light tier) layer ids, grouped by the
  /// palette role they get patched to. Captured 2026-07-29 by fetching
  /// `https://tiles.openfreemap.org/styles/liberty` directly and inspecting
  /// every layer's `id`/`type`/`source-layer` — see this class's doc comment
  /// for why hardcoded ids (checked against `getLayerIds()` before use)
  /// rather than a generic source-layer rule.
  static const _lightWaterFill = ['water'];
  static const _lightWaterwayLine = [
    'waterway_river',
    'waterway_other',
    'waterway_tunnel',
  ];
  static const _lightGreenFill = ['park', 'landcover_wood', 'landcover_grass'];
  static const _lightGreenLine = ['park_outline'];
  static const _lightUrbanGreenFill = ['landuse_residential'];
  static const _lightRoadCasingLine = [
    'tunnel_motorway_link_casing',
    'tunnel_service_track_casing',
    'tunnel_link_casing',
    'tunnel_street_casing',
    'tunnel_secondary_tertiary_casing',
    'tunnel_trunk_primary_casing',
    'tunnel_motorway_casing',
    'road_motorway_link_casing',
    'road_service_track_casing',
    'road_link_casing',
    'road_minor_casing',
    'road_secondary_tertiary_casing',
    'road_trunk_primary_casing',
    'bridge_motorway_link_casing',
    'bridge_service_track_casing',
    'bridge_link_casing',
    'bridge_street_casing',
    'bridge_path_pedestrian_casing',
    'bridge_secondary_tertiary_casing',
    'bridge_trunk_primary_casing',
    'bridge_motorway_casing',
  ];
  static const _lightRoadMainLine = [
    'tunnel_path_pedestrian',
    'tunnel_motorway_link',
    'tunnel_service_track',
    'tunnel_link',
    'tunnel_minor',
    'tunnel_secondary_tertiary',
    'tunnel_trunk_primary',
    'tunnel_motorway',
    'road_path_pedestrian',
    'road_motorway_link',
    'road_service_track',
    'road_link',
    'road_minor',
    'road_secondary_tertiary',
    'road_trunk_primary',
    'road_motorway',
    'bridge_path_pedestrian',
    'bridge_motorway_link',
    'bridge_service_track',
    'bridge_link',
    'bridge_street',
    'bridge_secondary_tertiary',
    'bridge_trunk_primary',
    'bridge_motorway',
  ];
  static const _lightRoadLabelSymbol = [
    'highway-name-path',
    'highway-name-minor',
    'highway-name-major',
  ];
  static const _lightPoiSymbol = ['poi_r7', 'poi_r1', 'poi_r20', 'poi_transit'];
  static const _lightBoundaryLine = [
    'boundary_2',
    'boundary_3',
    'boundary_disputed',
  ];

  /// OpenFreeMap `styles/dark` (dark tier) layer ids — a genuinely different
  /// id/schema set from `liberty` (see class doc comment), captured the same
  /// way. Notably has no POI layer at all, so there's nothing to patch there.
  static const _darkWaterFill = ['water'];
  static const _darkWaterwayLine = ['waterway'];
  static const _darkGreenFill = ['landcover_wood', 'landuse_park'];
  static const _darkUrbanGreenFill = ['landuse_residential'];
  static const _darkRoadCasingLine = [
    'highway_major_casing',
    'highway_motorway_casing',
  ];
  static const _darkRoadMainLine = [
    'highway_path',
    'highway_minor',
    'highway_major_inner',
    'highway_major_subtle',
    'highway_motorway_inner',
    'highway_motorway_subtle',
  ];
  static const _darkRoadLabelSymbol = [
    'highway_name_other',
    'highway_name_motorway',
  ];
  static const _darkBoundaryLine = [
    'boundary_state',
    'boundary_country_z0-4',
    'boundary_country_z5-',
  ];

  /// Call once from `onStyleLoadedCallback`, after the loader's own
  /// `onStyleLoaded()` — best-effort: an id absent from the loaded style
  /// (bundled fallback tier, or a future OpenFreeMap schema change) is
  /// silently skipped rather than throwing.
  static Future<void> apply(
    maplibre.MapLibreMapController controller, {
    required bool isDark,
  }) async {
    List existingIds;
    try {
      existingIds = await controller.getLayerIds();
    } catch (_) {
      return; // best-effort — an unrecolored basemap still fully functions
    }
    final present = existingIds.whereType<String>().toSet();

    Future<void> fill(List<String> ids, String color) => _applyToPresent(
      controller,
      present,
      ids,
      maplibre.FillLayerProperties(fillColor: color),
    );
    Future<void> line(List<String> ids, String color) => _applyToPresent(
      controller,
      present,
      ids,
      maplibre.LineLayerProperties(lineColor: color),
    );
    Future<void> label(List<String> ids) => _applyToPresent(
      controller,
      present,
      ids,
      const maplibre.SymbolLayerProperties(
        textColor: _roadLabelColor,
        textHaloColor: _roadLabelHalo,
        textFont: _notoSansRegular,
      ),
    );

    if (isDark) {
      await fill(_darkWaterFill, _waterMain);
      await line(_darkWaterwayLine, _waterShallow);
      await fill(_darkGreenFill, _landcoverGreen);
      await fill(_darkUrbanGreenFill, _landuseGreen);
      await line(_darkRoadCasingLine, _roadHalo);
      await line(_darkRoadMainLine, _roadTeal);
      await label(_darkRoadLabelSymbol);
      await line(_darkBoundaryLine, _boundaryColor);
    } else {
      await fill(_lightWaterFill, _waterMain);
      await line(_lightWaterwayLine, _waterShallow);
      await fill(_lightGreenFill, _landcoverGreen);
      await line(_lightGreenLine, _landcoverGreen);
      await fill(_lightUrbanGreenFill, _landuseGreen);
      await line(_lightRoadCasingLine, _roadHalo);
      await line(_lightRoadMainLine, _roadTeal);
      await label(_lightRoadLabelSymbol);
      await _applyToPresent(
        controller,
        present,
        _lightPoiSymbol,
        const maplibre.SymbolLayerProperties(
          textColor: _poiTextColor,
          textHaloColor: _poiHalo,
          textFont: _notoSansRegular,
        ),
      );
      await line(_lightBoundaryLine, _boundaryColor);
    }
  }

  static Future<void> _applyToPresent(
    maplibre.MapLibreMapController controller,
    Set<String> present,
    List<String> ids,
    maplibre.LayerProperties properties,
  ) async {
    for (final id in ids) {
      if (!present.contains(id)) continue;
      try {
        await controller.setLayerProperties(id, properties);
      } catch (_) {
        // Best-effort per-layer — one unexpected layer type/id mismatch
        // shouldn't abort the rest of the recolor pass.
      }
    }
  }

  // OpenFreeMap's vector tile source id, confirmed (2026-07-30) by fetching
  // both `styles/liberty` and `styles/dark` directly — both declare exactly
  // one vector source, `openmaptiles`, with a `building` source-layer
  // carrying `render_height`/`render_min_height` per feature (standard
  // OpenMapTiles fields).
  static const _buildingSourceId = 'openmaptiles';
  static const _buildingSourceLayer = 'building';

  /// `liberty`'s own id for its already-shipped fill-extrusion building
  /// layer (zoom >= 14, `hsl(35,8%,85%)`, opacity 0.8) — recolored in place
  /// rather than duplicated. `dark` ships no such layer at all (confirmed by
  /// the same fetch — only a flat 2D `building` fill), so that tier gets a
  /// new layer instead (see [_cityBuildingsLayerId]).
  static const _libertyBuilding3dLayerId = 'building-3d';
  static const _cityBuildingsLayerId = 'awaken-city-buildings';

  static const _buildingColorLight = '#8D97B3';
  static const _buildingColorDark = '#1E2436';

  /// Territory map 3D redesign §5.1: real city buildings, so captured
  /// territory sits inside a genuinely 3D world instead of floating over a
  /// flat map. Call once per style load, after [apply] — best-effort, same
  /// as [apply]: skipped entirely on a style/tier that doesn't carry the
  /// `building` source-layer (confirmed absent on the bundled offline
  /// fallback tier — callers should gate this out via
  /// `MapStyleLoader.isDegradedFallback` before calling, since that tier is
  /// a minimal low-zoom extract with no building data at all, not just a
  /// missing layer).
  static Future<void> applyCityBuildings(
    maplibre.MapLibreMapController controller, {
    required bool isDark,
  }) async {
    List existingIds;
    try {
      existingIds = await controller.getLayerIds();
    } catch (_) {
      return;
    }
    final present = existingIds.whereType<String>().toSet();
    final color = isDark ? _buildingColorDark : _buildingColorLight;

    if (present.contains(_libertyBuilding3dLayerId)) {
      try {
        await controller.setLayerProperties(
          _libertyBuilding3dLayerId,
          maplibre.FillExtrusionLayerProperties(
            fillExtrusionColor: color,
            fillExtrusionOpacity: 0.85,
          ),
        );
      } catch (_) {
        // Best-effort — an unrecolored (but still present, still 3D)
        // skyline is a fine degrade.
      }
      return;
    }

    if (present.contains(_cityBuildingsLayerId)) return;
    try {
      await controller.addFillExtrusionLayer(
        _buildingSourceId,
        _cityBuildingsLayerId,
        maplibre.FillExtrusionLayerProperties(
          fillExtrusionColor: color,
          fillExtrusionOpacity: 0.85,
          // Standard OpenMapTiles building-height pattern (same fields
          // `liberty`'s own `building-3d` layer reads) — a per-feature `get`
          // expression, not an interpolation, since the source data already
          // carries real building heights in meters.
          fillExtrusionBase: const ['get', 'render_min_height'],
          fillExtrusionHeight: const ['get', 'render_height'],
        ),
        sourceLayer: _buildingSourceLayer,
        minzoom: 14.5,
      );
    } catch (_) {
      // Best-effort — a tier whose vector source doesn't actually carry a
      // `building` source-layer (confirmed not the case for `liberty`/`dark`,
      // but a defensive catch for any future/unknown tier) just renders
      // without a city skyline.
    }
  }
}

/// Parameters for [buildTerritoryGeoJsonPayload] offloaded via `compute()`.
class TerritoryGeoJsonParams {
  final List<Territory> visible;
  final Set<String> atRiskIds;
  final Map<String, double> healthOfMap;
  final Set<String> squadMemberIds;
  final String ownedFillHex;
  final String squadmateFillHex;
  final String rivalFillHex;
  final String ownedOutlineHex;
  final String rivalOutlineHex;
  final String ownedExtrusionHex;
  final String squadmateExtrusionHex;
  final String rivalExtrusionHex;
  final double contestedRadiusM;

  const TerritoryGeoJsonParams({
    required this.visible,
    required this.atRiskIds,
    required this.healthOfMap,
    required this.squadMemberIds,
    required this.ownedFillHex,
    required this.squadmateFillHex,
    required this.rivalFillHex,
    required this.ownedOutlineHex,
    required this.rivalOutlineHex,
    required this.ownedExtrusionHex,
    required this.squadmateExtrusionHex,
    required this.rivalExtrusionHex,
    this.contestedRadiusM = 250.0,
  });
}

/// Result payload from [buildTerritoryGeoJsonPayload].
class TerritoryGeoJsonResult {
  final Map<String, dynamic> mainCollection;
  final Map<String, dynamic> wallCollection;
  final Map<String, dynamic> flagsCollection;
  final bool hasAtRisk;
  final bool hasContested;
  final bool hasRival;

  const TerritoryGeoJsonResult({
    required this.mainCollection,
    required this.wallCollection,
    required this.flagsCollection,
    required this.hasAtRisk,
    required this.hasContested,
    required this.hasRival,
  });
}

/// Top-level worker function for constructing GeoJSON feature collections off the UI thread via `compute()`.
TerritoryGeoJsonResult buildTerritoryGeoJsonPayload(
  TerritoryGeoJsonParams params,
) {
  final visible = params.visible;
  final rivalCentroids = [
    for (final t in visible)
      if (!t.isMine) TerritoryMapStyle.territoryCentroid(t),
  ];

  bool isContested(Territory territory) {
    if (!territory.isMine || rivalCentroids.isEmpty) return false;
    final centroid = TerritoryMapStyle.territoryCentroid(territory);
    for (final rivalCentroid in rivalCentroids) {
      if (TerritoryMapStyle.haversineMeters(centroid, rivalCentroid) <=
          params.contestedRadiusM) {
        return true;
      }
    }
    return false;
  }

  final contestedById = {for (final t in visible) t.id: isContested(t)};

  Map<String, dynamic> territoryFeatureProps(
    Territory territory,
    bool contested,
  ) {
    final isSquadmate =
        !territory.isMine && params.squadMemberIds.contains(territory.ownerId);
    final fillColor = territory.isMine
        ? params.ownedFillHex
        : (isSquadmate ? params.squadmateFillHex : params.rivalFillHex);
    final outlineColor = territory.isMine
        ? params.ownedOutlineHex
        : params.rivalOutlineHex;
    final extrusionColor = territory.isMine
        ? params.ownedExtrusionHex
        : (isSquadmate
              ? params.squadmateExtrusionHex
              : params.rivalExtrusionHex);

    final baseOpacity = territory.isMine ? 0.40 : 0.32;
    final health = territory.isMine
        ? (territory.health?.toDouble() ??
              params.healthOfMap[territory.id] ??
              100.0)
        : 100.0;
    final healthFactor = (0.4 + 0.6 * ((health - 25).clamp(0, 75) / 75)).clamp(
      0.4,
      1.0,
    );
    final targetOpacity = territory.isMine
        ? baseOpacity * healthFactor
        : baseOpacity;

    return {
      'owner': territory.isMine ? 'me' : 'rival',
      'ownerTier': territory.isMine
          ? 'me'
          : (isSquadmate ? 'squadmate' : 'rival'),
      'atRisk': territory.isMine && params.atRiskIds.contains(territory.id),
      'contested': contested,
      'areaSqm': territory.areaSqm,
      'fillColor': fillColor,
      'fillOpacity': targetOpacity,
      'outlineColor': outlineColor,
      'extrusionColor': extrusionColor,
    };
  }

  final propsById = {
    for (final t in visible)
      t.id: territoryFeatureProps(t, contestedById[t.id]!),
  };

  final features = [
    for (final territory in visible)
      TerritoryMapStyle.territoryToGeoJsonFeature(
        territory,
        propsById[territory.id]!,
      ),
  ];

  final wallFeatures = [
    for (final territory in visible)
      TerritoryMapStyle.territoryToWallGeoJsonFeature(
        territory,
        propsById[territory.id]!,
      ),
  ];

  final flagFeatures = [
    for (final territory in visible)
      for (final centroid in TerritoryMapStyle.territoryComponentCentroids(
        territory,
      ))
        {
          'type': 'Feature',
          'properties': {
            'id': territory.id,
            'flagColor': territory.isMine
                ? params.ownedExtrusionHex
                : (params.squadMemberIds.contains(territory.ownerId)
                      ? params.squadmateExtrusionHex
                      : params.rivalExtrusionHex),
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [centroid.longitude, centroid.latitude],
          },
        },
  ];

  final hasAtRisk = visible.any(
    (t) => t.isMine && params.atRiskIds.contains(t.id),
  );
  final hasContested = contestedById.values.any((c) => c);
  final hasRival = visible.any((t) => !t.isMine);

  return TerritoryGeoJsonResult(
    mainCollection: {'type': 'FeatureCollection', 'features': features},
    wallCollection: {'type': 'FeatureCollection', 'features': wallFeatures},
    flagsCollection: {'type': 'FeatureCollection', 'features': flagFeatures},
    hasAtRisk: hasAtRisk,
    hasContested: hasContested,
    hasRival: hasRival,
  );
}
