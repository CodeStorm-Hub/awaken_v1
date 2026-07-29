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
    final coordinates = [
      for (final rings in territory.polygons)
        [
          for (final ring in rings)
            if (ring.isNotEmpty)
              [
                for (final point in ring) [point.longitude, point.latitude],
                [ring.first.longitude, ring.first.latitude],
              ]
            else
              <List<double>>[],
        ],
    ];
    return {
      'type': 'Feature',
      'properties': {'id': territory.id, ...properties},
      'geometry': {'type': 'MultiPolygon', 'coordinates': coordinates},
    };
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
  static const _landuseGreen = '#82FD88'; // man-made green landuse (residential)
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
}
