import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/motion_tokens.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../../../squad/domain/entities/squad.dart';
import '../../../squad/domain/entities/squad_presence_member.dart';
import '../../../squad/domain/entities/territory_capture_feed_item.dart';
import '../../../squad/domain/usecases/get_recent_territory_captures.dart';
import '../../../squad/domain/usecases/watch_my_squad.dart';
import '../../../squad/domain/usecases/watch_squad_presence.dart';
import '../../domain/entities/bounty_zone.dart';
import '../../domain/entities/geo_bounds.dart';
import '../../domain/entities/rival.dart';
import '../../domain/entities/territory.dart';
import '../../domain/entities/territory_at_risk.dart';
import '../../domain/usecases/get_active_bounty_zones.dart';
import '../../domain/usecases/get_current_position.dart';
import '../../domain/usecases/get_current_rival.dart';
import '../../domain/usecases/get_territories_at_risk.dart';
import '../../domain/usecases/refresh_territories.dart';
import '../../domain/usecases/watch_owned_area.dart';
import '../../domain/usecases/watch_territories.dart';
import '../../../../sync/outbox/sync_worker.dart';
import '../../../../sync/sync_status.dart';
import '../widgets/map_style_loader.dart';
import '../widgets/map_style_overlays.dart';
import '../widgets/osm_attribution.dart';
import '../widgets/territory_map_style.dart';
import 'active_run_page.dart';

/// Territory map (plan §6 Phase 5c, redesigned per the territory feature
/// review). Real vector-tile rendering via `maplibre_gl` — replaces the
/// earlier `flutter_map` raster setup, which couldn't consume OpenFreeMap's
/// tiles (vector-only) without a much larger integration. The `MapLibreMap`
/// widget is built exactly once and never rebuilt from state changes;
/// territory polygons are synced onto it *imperatively* via a single
/// `GeoJsonSource` (`addGeoJsonSource`/`setGeoJsonSource`) feeding
/// `FillLayerProperties`/`LineLayerProperties` layers, so the native map
/// view is never torn down and re-created — that rebuild-on-every-change
/// pattern was the direct cause of this page's earlier map/GPS-page
/// choppiness. Non-territory markers (position dot, neutral-zone ring,
/// bounty zones) still use the simpler `Fill`/`Circle` annotation API, which
/// is fine for infrequently-redrawn, non-animated shapes.
class TerritoryPage extends StatefulWidget {
  const TerritoryPage({super.key});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  MapLibreMapController? _controller;
  StreamSubscription<List<Territory>>? _territoriesSub;
  List<Territory> _lastTerritories = const [];

  // Territory fill/outline rendering (items 2/3/5/6/7) runs entirely off one
  // `GeoJsonSource` + two style layers instead of per-territory `Fill`/`Line`
  // annotations — see this file's class doc comment. `_territoryLayersReady`
  // guards the one-time `addGeoJsonSource`/`addLayer` calls; later redraws
  // just call `setGeoJsonSource` on the existing source. Rival territory's
  // dashed outline (item 3) is a real `line-dasharray` data expression on
  // `_territoryOutlineLayerId` now — no more broken-segment faking (compare
  // the now-deleted `TerritoryMapStyle.ringToDashSegments`). The pulsing
  // at-risk border (item 5) is a second, filtered outline layer
  // (`_territoryAtRiskOutlineLayerId`) whose `lineWidth`/`lineOpacity` are
  // ticked via `setLayerProperties` instead of re-adding `Line` annotations.
  static const _territorySourceId = 'territories-source';
  static const _territoryFillLayerId = 'territories-fill-layer';
  static const _territoryOutlineLayerId = 'territories-outline-layer';
  static const _territoryExtrusionLayerId = 'territories-extrusion-layer';
  static const _territoryAtRiskOutlineLayerId =
      'territories-atrisk-outline-layer';
  bool _territoryLayersReady = false;

  /// True once `onStyleLoadedCallback` has fired for the current native map
  /// view. `_controller` goes non-null at `onMapCreated`, *before* the style
  /// finishes loading — `_redrawSquadHeatmap` can be triggered independently
  /// of the map's own lifecycle (via `_loadSquadInfo`'s squad-membership
  /// stream, set up in `initState`), so a `controller != null` check alone
  /// isn't enough to guarantee `addFillLayer`/`addGeoJsonSource` are safe to
  /// call — confirmed live: `PlatformException(STYLE_NOT_READY, ...)` fired
  /// on real device/emulator testing when the squad stream's first value
  /// arrived before the style finished loading.
  bool _styleReady = false;

  /// "3D view" toggle (skyline redesign item) — animates camera `tilt`
  /// between 0 and 45deg so the fill-extrusion "skyline" layer
  /// (`_territoryExtrusionLayerId`) is actually visible; at tilt 0 an
  /// extrusion renders identically to its flat footprint, so without this
  /// the whole layer would be invisible by default.
  bool _is3D = false;
  Timer? _pulseTimer;
  double _pulseT = 0;

  /// Animated "ant path" dashed rival outline — steps
  /// `_territoryOutlineLayerId`'s rival-branch `line-dasharray` through
  /// [_antPathDashSequence] on a timer, same structural pattern as
  /// `_pulseTimer`/`_tickPulse` above (including the reduce-motion guard in
  /// `_updateAntPathTimer`, mirroring `_updatePulseTimer`'s
  /// `hasAtRisk`-gating). The OWNED branch of the outline layer's `case`
  /// expression always stays `[1, 0]` (solid) — only the rival branch's
  /// dasharray value cycles.
  Timer? _antPathTimer;
  int _antPathStep = 0;

  /// The standard MapLibre/Mapbox GL JS "ant path" dash-array sequence —
  /// each step nudges the dash pattern's phase, so animating through them in
  /// order reads as a marching/flowing dashed line rather than a static one.
  static const _antPathDashSequence = <List<double>>[
    [0, 4, 3],
    [0.5, 4, 2.5],
    [1, 4, 2],
    [1.5, 4, 1.5],
    [2, 4, 1],
    [2.5, 4, 0.5],
    [3, 4, 0],
    [0, 0.5, 3, 3.5],
    [0, 1, 3, 3],
    [0, 1.5, 3, 2.5],
    [0, 2, 3, 2],
    [0, 2.5, 3, 1.5],
    [0, 3, 3, 1],
    [0, 3.5, 3, 0.5],
  ];

  // Ids of owned territories from the *previous* redraw — a territory that
  // is mine now but wasn't a moment ago just got captured, and gets the
  // grow-in animation (item 7) instead of popping in at full opacity.
  Set<String> _knownMineIds = {};

  LatLng _center = const LatLng(20, 0);
  bool _hasFix = false;
  bool _showRivalTerritory = true;

  late final _styleLoader = MapStyleLoader(
    onChange: () => setState(() {}),
    isDark: Theme.of(context).brightness == Brightness.dark,
  );

  final _bountyFillsByZoneId = <String, List<Fill>>{};
  Rival? _currentRival;
  List<TerritoryAtRisk> _atRisk = const [];

  // Unclaimed/"capturable" ground near the user (item 4) — a subtle
  // neutral-tinted ring around the last known fix, Ingress-style, so the
  // map reads as "you can capture this" rather than empty space.
  Fill? _neutralZoneFill;

  // Squad territory heatmap (item 11) — client-side aggregation of
  // already-fetched `Territory` rows (via `ownerId`) against the caller's
  // squad's online member ids. `SquadRepository` doesn't expose a
  // dedicated "all my squad's territory" query, so this reuses whatever
  // territories are already cached/visible in the current viewport rather
  // than fetching a separate global set. Own `GeoJsonSource`/`FillLayer`
  // (not folded into the main territory source above) so it can be toggled
  // on/off cheaply via `setLayerVisibility` instead of add/remove churn.
  static const _squadHeatmapSourceId = 'squad-heatmap-source';
  static const _squadHeatmapFillLayerId = 'squad-heatmap-fill-layer';
  bool _squadHeatmapLayerReady = false;
  Squad? _mySquad;
  Set<String> _squadMemberIds = {};
  StreamSubscription<Squad?>? _squadSub;
  StreamSubscription<List<SquadPresenceMember>>? _presenceSub;
  bool _showSquadHeatmap = false;

  // Clustered bounty-zone markers (skyline redesign item 3) — a *separate*
  // point source/layers from `_bountyFillsByZoneId`'s existing translucent
  // radius `Fill`s above: those show *where a bounty's effect radius is*,
  // this shows *discrete bounty locations as markers*, clustering when
  // several are close together at low zoom (`GeojsonSourceProperties`'s
  // `cluster`/`clusterRadius`/`clusterMaxZoom` — see `addSource`'s doc
  // comment on this file's imports). Uses `addSource` + `setGeoJsonSource`
  // rather than `addGeoJsonSource`, since clustering params only exist on
  // `GeojsonSourceProperties` (`addGeoJsonSource` has no clustering args).
  static const _bountyMarkersSourceId = 'bounty-zones-source';
  static const _bountyClusterCircleLayerId = 'bounty-zones-cluster-circle-layer';
  static const _bountyClusterCountLayerId = 'bounty-zones-cluster-count-layer';
  static const _bountyUnclusteredLayerId = 'bounty-zones-unclustered-layer';
  bool _bountyMarkersLayerReady = false;

  // Capture-density heatmap (item 4 — 2026-07-29 territory review) —
  // `recent_territory_captures()` rows with a known lat/lng, rendered as a
  // `HeatmapLayerProperties` layer. Toggleable via the "Map layers" sheet,
  // same lazy-add/`setLayerVisibility` pattern as `_showSquadHeatmap`
  // above. Old rows (before the lat/lng migration) have null coordinates
  // and are filtered out rather than faked.
  static const _captureHeatmapSourceId = 'capture-heatmap-source';
  static const _captureHeatmapLayerId = 'capture-heatmap-layer';
  bool _captureHeatmapLayerReady = false;
  bool _showCaptureHeatmap = false;
  Timer? _captureHeatmapRefetchTimer;

  // Clustered squad-member location markers (item 5) — same clustered
  // point-source structure as `_bountyMarkersSourceId`'s bounty markers
  // above (`GeojsonSourceProperties(cluster: true, ...)` + an unclustered
  // circle layer + a cluster-bubble circle layer + a cluster-count symbol
  // layer), fed from `WatchSquadPresence`'s already-live stream
  // (`_loadSquadInfo`) instead of a separate fetch. A distinct blue tint
  // (`scheme.secondary`) keeps it visually apart from bounty gold and the
  // territory owned/rival colors.
  static const _squadMemberMarkersSourceId = 'squad-member-markers-source';
  static const _squadMemberClusterCircleLayerId =
      'squad-member-markers-cluster-circle-layer';
  static const _squadMemberClusterCountLayerId =
      'squad-member-markers-cluster-count-layer';
  static const _squadMemberUnclusteredLayerId =
      'squad-member-markers-unclustered-layer';
  bool _squadMemberMarkersLayerReady = false;
  List<SquadPresenceMember> _squadPresenceMembers = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_locateSelf());
    unawaited(_loadRivalAndDecayStatus());
    _loadSquadInfo();
    // Same cadence as the Squad page's "conquest ticker" refetch
    // (`_ConquestTickerState._refetchInterval`) — only actually redraws
    // while the layer is toggled on, so this is a cheap no-op the rest of
    // the time.
    _captureHeatmapRefetchTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      if (_showCaptureHeatmap) unawaited(_redrawCaptureHeatmap());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Corrects the map for the `IndexedStack`-eager-build/`ThemeModeCubit`-
    // async-load race the `_styleLoader` field's doc comment describes —
    // also picks up any later in-session theme toggle for free.
    _styleLoader.updateBrightness(
      Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// Neither of these is viewport-scoped like territories/bounty zones —
  /// fetched once per page open rather than per camera move.
  Future<void> _loadRivalAndDecayStatus() async {
    try {
      final results = await Future.wait([
        getIt<GetCurrentRival>()(const NoParams()),
        getIt<GetTerritoriesAtRisk>()(const NoParams()),
      ]);
      if (!mounted) return;
      setState(() {
        _currentRival = results[0] as Rival?;
        _atRisk = results[1] as List<TerritoryAtRisk>;
      });
    } catch (_) {
      // Best-effort — the map/run-tracking core functionality doesn't
      // depend on either of these loading successfully.
    }
  }

  @override
  void dispose() {
    unawaited(_territoriesSub?.cancel());
    unawaited(_squadSub?.cancel());
    unawaited(_presenceSub?.cancel());
    _bboxRefreshDebounceTimer?.cancel();
    _pulseTimer?.cancel();
    _antPathTimer?.cancel();
    _captureHeatmapRefetchTimer?.cancel();
    _styleLoader.dispose();
    super.dispose();
  }

  /// Best-effort — the caller may not be in a squad, and squad membership
  /// isn't needed for the map's core owned/rival territory rendering, only
  /// for the optional heatmap layer toggle.
  void _loadSquadInfo() {
    _squadSub = getIt<WatchMySquad>()().listen((squad) {
      unawaited(_presenceSub?.cancel());
      _mySquad = squad;
      if (squad == null) {
        if (mounted) setState(() => _squadMemberIds = {});
        _squadPresenceMembers = const [];
        unawaited(_redrawSquadHeatmap());
        unawaited(_redrawSquadMemberMarkers());
        return;
      }
      _presenceSub = getIt<WatchSquadPresence>()(squad.id).listen((members) {
        if (!mounted) return;
        setState(() {
          _squadMemberIds = members.map((m) => m.userId).toSet();
        });
        _squadPresenceMembers = members;
        unawaited(_redrawSquadHeatmap());
        unawaited(_redrawSquadMemberMarkers());
      });
    });
  }

  Future<void> _locateSelf() async {
    try {
      final position = await getIt<GetCurrentPosition>()(const NoParams());
      if (position == null || !mounted) return;
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _hasFix = true;
      });
      final controller = _controller;
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_center, _focusZoom),
        );
        await _syncCurrentPositionMarker();
        await _syncNeutralZone();
        // Explicit, rather than relying on `animateCamera` reliably
        // triggering `onCameraIdle` on its own (plugin behavior this
        // shouldn't have to depend on). Real gap found live: `initState`
        // calls this concurrently with the native map's own async style
        // load — if the style finishes first, `_onStyleLoaded`'s initial
        // refresh runs against the still-default (unrelated) camera
        // position, and without this explicit follow-up, nothing ever
        // corrects it for the region the user is actually in.
        await _refreshForCurrentView();
      }
    } catch (_) {
      // Best-effort centering only — a failed/denied fix just keeps the
      // fallback view; the map (and starting a run) still works.
    }
  }

  Circle? _positionMarker;

  Future<void> _syncCurrentPositionMarker() async {
    final controller = _controller;
    if (controller == null || !_hasFix) return;
    final scheme = Theme.of(context).colorScheme;
    if (_positionMarker == null) {
      _positionMarker = await controller.addCircle(
        CircleOptions(
          geometry: _center,
          circleRadius: 7,
          circleColor: _colorToHex(scheme.primary),
          circleStrokeColor: _colorToHex(scheme.surface),
          circleStrokeWidth: 2,
        ),
      );
    } else {
      await controller.updateCircle(
        _positionMarker!,
        CircleOptions(geometry: _center),
      );
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    // A fallback-tier style swap tears down and recreates the native map
    // view entirely (see MapStyleLoader) — any Fill/Line handles, and any
    // previously-added GeoJSON sources/layers, belong to a now-destroyed
    // view. The new view starts with none, so both the territory layers and
    // the squad heatmap layer need their one-time `addGeoJsonSource`/
    // `addLayer` setup to run again.
    _bountyFillsByZoneId.clear();
    _territoryLayersReady = false;
    _squadHeatmapLayerReady = false;
    _bountyMarkersLayerReady = false;
    _captureHeatmapLayerReady = false;
    _squadMemberMarkersLayerReady = false;
    _styleReady = false;
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _antPathTimer?.cancel();
    _antPathTimer = null;
    // Missed here previously: the marker handle from before the swap also
    // belongs to the now-destroyed view, so `_syncCurrentPositionMarker`'s
    // `updateCircle` on the stale handle silently no-oped against the new
    // one — the blue position dot never reappeared after a style-tier
    // fallback, even though fills/bounty zones correctly redrew.
    _positionMarker = null;
    _neutralZoneFill = null;
    _controller = controller;
    _styleLoader.start();
  }

  Future<void> _onStyleLoaded() async {
    _styleLoader.onStyleLoaded();
    _styleReady = true;
    // The squad-membership stream (`_loadSquadInfo`) is independent of the
    // map's own lifecycle and may have already tried (and silently failed
    // to run any layer calls) while the style was still loading — replay it
    // once now that it's safe.
    unawaited(_redrawSquadHeatmap());
    final controller = _controller;
    if (controller != null) {
      // Pokémon-GO-inspired basemap recolor (item — see
      // `TerritoryBasemapRecolor`'s doc comment for why this runs here,
      // per-style-load via `setLayerProperties`, rather than pre-patching
      // the style JSON). Best-effort and idempotent — safe to await inline,
      // and must re-run on every style (re)load, including a fallback-tier
      // swap, since that's a brand new native view with the recolor undone.
      unawaited(
        TerritoryBasemapRecolor.apply(
          controller,
          isDark: mounted && Theme.of(context).brightness == Brightness.dark,
        ),
      );
    }
    if (_hasFix) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_center, _focusZoom),
      );
      await _syncCurrentPositionMarker();
      await _syncNeutralZone();
    }
    await _refreshForCurrentView();
    // A fallback-tier style swap tears down and recreates the native map
    // view (see MapStyleLoader), so this can run more than once per page
    // lifetime — cancel any previous subscription first to avoid piling up
    // duplicate listeners.
    await _territoriesSub?.cancel();
    _territoriesSub = getIt<WatchTerritories>()().listen(_onTerritoriesChanged);
    unawaited(_drawBountyZones());
    unawaited(_redrawCaptureHeatmap());
  }

  /// Unclaimed, runnable ground near the user (item 4) — a subtle
  /// `territoryNeutral`-tinted ring around the last known fix, so the map
  /// reads as "this is capturable" rather than empty space (Ingress-style
  /// neutral/faction painting). Drawn once per fix rather than tracked
  /// continuously with the position marker, since it's meant to read as
  /// "the area around here," not a precise live radius.
  Future<void> _syncNeutralZone() async {
    final controller = _controller;
    if (controller == null || !_hasFix || !mounted) return;
    final semantic = context.semanticColors;
    final ring = _circlePolygon(_center.latitude, _center.longitude, 300);
    if (_neutralZoneFill == null) {
      _neutralZoneFill = await controller.addFill(
        FillOptions(
          geometry: [ring],
          fillColor: _colorToHex(semantic.territoryNeutral),
          fillOpacity: 0.08,
          fillOutlineColor: _colorToHex(semantic.territoryNeutral),
        ),
      );
    } else {
      await controller.updateFill(
        _neutralZoneFill!,
        FillOptions(geometry: [ring]),
      );
    }
  }

  /// Bounty zones are few and global (not per-viewport like territories),
  /// so this fetches once per style load rather than on every camera move.
  Future<void> _drawBountyZones() async {
    final controller = _controller;
    if (controller == null) return;
    List<BountyZone> zones;
    try {
      zones = await getIt<GetActiveBountyZones>()(const NoParams());
    } catch (_) {
      return; // best-effort — a failed fetch just means no bounty layer this session
    }
    if (!mounted || _controller == null) return;

    // `_onStyleLoaded` can run more than once per page lifetime on the
    // *same* controller (e.g. a style-quality upgrade after the initial
    // fallback tier, not just a full view recreation) — without clearing
    // first, a second draw stacked a duplicate translucent fill on top of
    // the first per zone, each redraw darkening the overlay further.
    final existingFills = _bountyFillsByZoneId.values.expand((f) => f).toList();
    if (existingFills.isNotEmpty) {
      await controller.removeFills(existingFills);
    }
    _bountyFillsByZoneId.clear();
    if (!mounted) return;
    final semantic = context.semanticColors;

    for (final zone in zones) {
      final ring = _circlePolygon(zone.centerLat, zone.centerLng, zone.radiusM);
      final fill = await controller.addFill(
        FillOptions(
          geometry: [ring],
          fillColor: _colorToHex(semantic.bountyGold),
          fillOpacity: 0.25,
          fillOutlineColor: _colorToHex(semantic.bountyGold),
        ),
      );
      _bountyFillsByZoneId[zone.id] = [fill];
    }

    unawaited(_drawBountyMarkers(zones));
  }

  /// Clustered bounty-zone center markers (skyline redesign item 3) —
  /// distinct from the translucent radius `Fill`s drawn just above: those
  /// show a zone's effect radius, this shows discrete bounty *locations* as
  /// point markers, clustering nearby ones at low zoom so a dense cluster of
  /// bounties doesn't render as an unreadable pile of overlapping dots.
  Future<void> _drawBountyMarkers(List<BountyZone> zones) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final semantic = context.semanticColors;
    final goldHex = _colorToHex(semantic.bountyGold);

    final collection = {
      'type': 'FeatureCollection',
      'features': [
        for (final zone in zones)
          {
            'type': 'Feature',
            'properties': {'id': zone.id, 'multiplier': zone.multiplier},
            'geometry': {
              'type': 'Point',
              'coordinates': [zone.centerLng, zone.centerLat],
            },
          },
      ],
    };

    if (!_bountyMarkersLayerReady) {
      await controller.addSource(
        _bountyMarkersSourceId,
        GeojsonSourceProperties(
          data: collection,
          cluster: true,
          clusterRadius: 50,
          clusterMaxZoom: 14,
        ),
      );
      // Individual (unclustered) bounty markers — gold-toned per
      // `context.semanticColors.bountyGold`, matching the radius fill and
      // the badge `TerritoryCaptureSheet` already shows for bounty
      // captures. `['!', ['has', 'point_count']]` is the standard
      // MapLibre/Mapbox pattern for "not a cluster" — only cluster
      // features get a synthetic `point_count` property.
      await controller.addCircleLayer(
        _bountyMarkersSourceId,
        _bountyUnclusteredLayerId,
        CircleLayerProperties(
          circleRadius: 8,
          circleColor: goldHex,
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
        filter: [
          '!',
          ['has', 'point_count'],
        ],
      );
      // Cluster bubbles — filtered to `['has', 'point_count']` (the
      // inverse of the unclustered filter above).
      await controller.addCircleLayer(
        _bountyMarkersSourceId,
        _bountyClusterCircleLayerId,
        CircleLayerProperties(
          circleRadius: 16,
          circleColor: goldHex,
          circleOpacity: 0.85,
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
        filter: ['has', 'point_count'],
      );
      // Cluster count label — `point_count_abbreviated` (e.g. "1.2k") is
      // the standard MapLibre/Mapbox cluster-count text-field expression.
      await controller.addSymbolLayer(
        _bountyMarkersSourceId,
        _bountyClusterCountLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'point_count_abbreviated'],
          textSize: 12,
          textColor: '#1C1C1E',
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        filter: ['has', 'point_count'],
      );
      _bountyMarkersLayerReady = true;
    } else {
      // Per `setGeoJsonSource`'s own doc comment this "only works as
      // expected" for sources created via `addGeoJsonSource` — this source
      // was created via `addSource` instead (required for the `cluster`
      // param, which `addGeoJsonSource` doesn't expose). In practice both
      // create the same underlying native "geojson" source type and
      // `setGeoJsonSource` updates it by id regardless of which call
      // created it; bounty zones also only redraw once per style load (see
      // this method's caller), so this path is rarely exercised anyway.
      await controller.setGeoJsonSource(_bountyMarkersSourceId, collection);
    }
  }

  /// A 32-point polygon approximating a [radiusMeters] circle around
  /// (lat, lng) — MapLibre's `CircleOptions.circleRadius` is in screen
  /// pixels, not meters, so it can't represent a real-world-sized zone that
  /// stays accurate across zoom levels; a `Fill` polygon (same primitive
  /// territories already use) does.
  static List<LatLng> _circlePolygon(
    double lat,
    double lng,
    double radiusMeters,
  ) {
    const points = 32;
    const earthRadiusM = 6371000.0;
    final latRad = lat * (math.pi / 180);
    final ring = <LatLng>[];
    for (var i = 0; i <= points; i++) {
      final angle = 2 * math.pi * i / points;
      final dLat =
          (radiusMeters * math.cos(angle)) / earthRadiusM * (180 / math.pi);
      final dLng =
          (radiusMeters * math.sin(angle)) /
          (earthRadiusM * math.cos(latRad)) *
          (180 / math.pi);
      ring.add(LatLng(lat + dLat, lng + dLng));
    }
    return ring;
  }

  void _onTerritoriesChanged(List<Territory> territories) {
    _lastTerritories = territories;
    unawaited(_redrawFills());
    unawaited(_redrawSquadHeatmap());
  }

  /// Fallback health (0-100) for an owned territory, derived from
  /// `TerritoryAtRisk.lastDefendedAt`/`expiresAt` — used only when
  /// `Territory.health` is null (a row cached before `territories_in_bbox()`
  /// started returning the real server-computed `health` column, i.e. a
  /// cache-migration safety net, not the normal path anymore). A territory
  /// absent from the at-risk list is outside the decay warning window
  /// entirely, i.e. full health.
  double _healthOf(
    String territoryId,
    Map<String, TerritoryAtRisk> atRiskById,
  ) {
    final risk = atRiskById[territoryId];
    if (risk == null) return 100;
    final totalWindowSec = risk.expiresAt
        .difference(risk.lastDefendedAt)
        .inSeconds;
    if (totalWindowSec <= 0) return 0;
    final remainingSec = risk.expiresAt.difference(DateTime.now()).inSeconds;
    return (remainingSec / totalWindowSec * 100).clamp(0, 100).toDouble();
  }

  /// Feature properties consumed by the territory fill/outline layers' data
  /// expressions (see `_redrawFills`) — `owner`/`atRisk` drive the rival
  /// dashed outline and the at-risk-outline layer's `filter`, `fillColor`/
  /// `fillOpacity`/`outlineColor` carry this file's existing ownership-color
  /// (item 2) and health-decay-opacity (item 6) logic, computed in Dart
  /// exactly as before — only *where* the result is applied changed (a
  /// GeoJSON property instead of a `FillOptions`/`LineOptions` argument).
  Map<String, dynamic> _territoryFeatureProperties(
    Territory territory,
    Map<String, TerritoryAtRisk> atRiskById,
  ) {
    final semantic = context.semanticColors;
    final fillColor = territory.isMine
        ? semantic.territoryOwnedFill
        : semantic.territoryRivalFill;
    final outlineColor = territory.isMine
        ? semantic.territoryOwned
        : semantic.territoryRival;

    final baseOpacity = territory.isMine ? 0.40 : 0.32;
    // Real server-computed decay value now (`territories_in_bbox()`'s
    // `health` column) — falls back to the client-side at-risk-window
    // approximation only for rows cached before that column existed (see
    // `_healthOf`'s doc comment), so a stale local cache never hard-crashes
    // on missing data.
    final health = territory.isMine
        ? (territory.health?.toDouble() ?? _healthOf(territory.id, atRiskById))
        : 100.0;
    final healthFactor = (0.4 + 0.6 * ((health - 25).clamp(0, 75) / 75))
        .clamp(0.4, 1.0);
    final targetOpacity = territory.isMine
        ? baseOpacity * healthFactor
        : baseOpacity;

    return {
      'owner': territory.isMine ? 'me' : 'rival',
      'atRisk': territory.isMine && atRiskById.containsKey(territory.id),
      'areaSqm': territory.areaSqm,
      'fillColor': _colorToHex(fillColor),
      'fillOpacity': targetOpacity,
      'outlineColor': _colorToHex(outlineColor),
    };
  }

  Future<void> _redrawFills() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final semantic = context.semanticColors;
    final atRiskById = {for (final t in _atRisk) t.id: t};

    // A territory that's mine now but wasn't a moment ago just got
    // captured (item 7) — animated in via `_animateCaptureGrowIn` below
    // instead of popping straight to full opacity.
    final currentMineIds = _lastTerritories
        .where((t) => t.isMine)
        .map((t) => t.id)
        .toSet();
    final newlyCaptured = currentMineIds.difference(_knownMineIds);
    _knownMineIds = currentMineIds;

    final visible = _lastTerritories.where(
      (t) => t.isMine || _showRivalTerritory,
    );
    final features = [
      for (final territory in visible)
        TerritoryMapStyle.territoryToGeoJsonFeature(
          territory,
          _territoryFeatureProperties(territory, atRiskById),
        ),
    ];
    final collection = {'type': 'FeatureCollection', 'features': features};

    if (!_territoryLayersReady) {
      await controller.addGeoJsonSource(_territorySourceId, collection);
      await controller.addFillLayer(
        _territorySourceId,
        _territoryFillLayerId,
        const FillLayerProperties(
          fillColor: ['get', 'fillColor'],
          fillOpacity: ['get', 'fillOpacity'],
          fillOutlineColor: ['get', 'outlineColor'],
        ),
      );
      // Rival territory's dashed outline (item 3) is a real data-driven
      // `line-dasharray` expression now — `[1, 0]` (dash length 1, gap 0)
      // reads as solid for everyone else. Replaces
      // `TerritoryMapStyle.ringToDashSegments`'s broken-line-segment fake,
      // which existed only because the old annotation-manager `LineOptions`
      // had no dash-pattern paint property at all.
      await controller.addLineLayer(
        _territorySourceId,
        _territoryOutlineLayerId,
        const LineLayerProperties(
          lineColor: ['get', 'outlineColor'],
          lineWidth: 2,
          lineDasharray: [
            'case',
            ['==', ['get', 'owner'], 'rival'],
            ['literal', [2, 1.5]],
            ['literal', [1, 0]],
          ],
        ),
      );
      // Territory "skyline" (skyline redesign item 1) — a 3D fill-extrusion
      // reading the *same* `_territorySourceId` source (the geometry's
      // already there; no new source needed). `belowLayerId:
      // _territoryOutlineLayerId` places it directly under the outline
      // layer added just above — outlines (and, below that call, the
      // at-risk pulse border) still draw crisply on top of the extruded
      // blocks instead of getting buried under a 3D face. `fillColor`
      // reuses the exact `['get', 'fillColor']` expression the flat fill
      // layer uses so owned/rival coloring stays consistent between the
      // flat 2D view and the tilted 3D one. Height is only ever visible
      // once the user tilts the camera via the "3D view" toggle
      // (`_toggle3DView`) — at tilt 0 an extrusion renders identically to
      // its flat footprint, so this is a no-op visually until then.
      await controller.addFillExtrusionLayer(
        _territorySourceId,
        _territoryExtrusionLayerId,
        const FillExtrusionLayerProperties(
          fillExtrusionColor: ['get', 'fillColor'],
          fillExtrusionOpacity: 0.8,
          fillExtrusionBase: 0.0,
          // Awaken's captured areas run roughly tens-to-low-hundreds of sqm
          // for a typical loop up through several thousand sqm for a large
          // run (plan's territory pipeline works in real m² via `::geography`
          // casts — see CLAUDE.md). Breakpoints picked so a small capture
          // still reads as a visible block (not flush with the ground) while
          // a large one caps out at a readable "skyline" height rather than
          // growing unboundedly.
          fillExtrusionHeight: [
            'interpolate',
            ['linear'],
            ['get', 'areaSqm'],
            0, 0,
            250, 40,
            2500, 100,
            20000, 160,
          ],
        ),
        belowLayerId: _territoryOutlineLayerId,
      );
      // Pulsing at-risk border (item 5) — a second outline layer reading
      // the same source, filtered to only at-risk features via the style
      // `filter` (not a paint expression), so `_tickPulse` can animate its
      // width/opacity for every at-risk territory with one
      // `setLayerProperties` call instead of iterating `Line` handles.
      await controller.addLineLayer(
        _territorySourceId,
        _territoryAtRiskOutlineLayerId,
        LineLayerProperties(
          lineColor: _colorToHex(semantic.territoryAtRisk),
          lineWidth: 3,
          lineOpacity: 1.0,
        ),
        filter: ['==', ['get', 'atRisk'], true],
      );
      _territoryLayersReady = true;
    } else {
      await controller.setGeoJsonSource(_territorySourceId, collection);
    }

    final hasAtRisk = visible.any(
      (t) => t.isMine && atRiskById.containsKey(t.id),
    );
    _updatePulseTimer(hasAtRisk);

    final hasRival = visible.any((t) => !t.isMine);
    _updateAntPathTimer(hasRival);

    if (newlyCaptured.isNotEmpty) {
      unawaited(_animateCaptureGrowIn(newlyCaptured));
    }
  }

  /// Capture is an event, not a state swap (item 7): a newly-captured
  /// territory's fill ramps from transparent to its target opacity over
  /// `MotionTokens.defaultSpatial` (~500ms) instead of popping straight to
  /// full color. Driven by a real paint-property animation now — repeated
  /// `setLayerProperties` calls on the fill layer's `fillOpacity`, using a
  /// `case` expression that multiplies just the newly-captured features'
  /// (matched by `id`) opacity by the current step fraction and leaves every
  /// other feature reading its own `fillOpacity` property untouched. Once
  /// the ramp finishes, the layer's `fillOpacity` is reset to the plain
  /// `["get", "fillOpacity"]` expression so a later `setGeoJsonSource`
  /// update (e.g. health decay) isn't masked by a stale `case` still
  /// matching now-settled ids.
  Future<void> _animateCaptureGrowIn(Set<String> capturedIds) async {
    if (capturedIds.isEmpty) return;
    final controllerAtStart = _controller;
    if (controllerAtStart == null) return;
    const restingExpression = FillLayerProperties(
      fillOpacity: ['get', 'fillOpacity'],
    );
    if (mounted && MediaQuery.disableAnimationsOf(context)) {
      await controllerAtStart.setLayerProperties(
        _territoryFillLayerId,
        restingExpression,
      );
      return;
    }
    const steps = 6;
    final stepMs = (MotionTokens.defaultSpatial.inMilliseconds / steps).round();
    final idsList = capturedIds.toList();
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(Duration(milliseconds: stepMs));
      // A style-tier swap tears down and recreates the native map view
      // mid-animation, and its layers belong to a destroyed view — bail
      // rather than call `setLayerProperties` against a stale controller.
      if (_controller != controllerAtStart || !_territoryLayersReady) return;
      final fraction = i / steps;
      await controllerAtStart.setLayerProperties(
        _territoryFillLayerId,
        FillLayerProperties(
          fillOpacity: [
            'case',
            ['in', ['get', 'id'], ['literal', idsList]],
            ['*', ['get', 'fillOpacity'], fraction],
            ['get', 'fillOpacity'],
          ],
        ),
      );
    }
    if (_controller == controllerAtStart && _territoryLayersReady) {
      await controllerAtStart.setLayerProperties(
        _territoryFillLayerId,
        restingExpression,
      );
    }
  }

  /// Starts/stops the periodic `setLayerProperties` ticker driving the
  /// pulsing at-risk border (item 5). Guarded by
  /// `MediaQuery.disableAnimationsOf` for reduce-motion — a static
  /// (non-pulsing, still-present) border still gets drawn by
  /// `_territoryAtRiskOutlineLayerId`'s `filter` either way, so
  /// reduce-motion users don't lose the at-risk signal, only its animation.
  void _updatePulseTimer(bool hasAtRisk) {
    if (!hasAtRisk) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      return;
    }
    if (_pulseTimer != null) return;
    if (mounted && MediaQuery.disableAnimationsOf(context)) return;
    _pulseTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => unawaited(_tickPulse()),
    );
  }

  Future<void> _tickPulse() async {
    final controller = _controller;
    if (controller == null || !_territoryLayersReady) return;
    _pulseT += 0.12;
    final t = (math.sin(_pulseT * math.pi) + 1) / 2; // 0..1..0 loop
    final width = 2.0 + t * 3.0;
    final opacity = 0.5 + t * 0.5;
    await controller.setLayerProperties(
      _territoryAtRiskOutlineLayerId,
      LineLayerProperties(lineWidth: width, lineOpacity: opacity),
    );
  }

  /// Starts/stops the periodic `setLayerProperties` ticker driving the
  /// rival "ant path" dashed outline (item 3) — same
  /// gate/reduce-motion-guard structure as `_updatePulseTimer` above. A
  /// static (non-animated, still dashed via the outline layer's original
  /// `case` expression) rival outline is drawn regardless either way, so
  /// reduce-motion users still get the dashed-vs-solid ownership cue, just
  /// not the marching animation.
  void _updateAntPathTimer(bool hasRival) {
    if (!hasRival) {
      _antPathTimer?.cancel();
      _antPathTimer = null;
      return;
    }
    if (_antPathTimer != null) return;
    if (mounted && MediaQuery.disableAnimationsOf(context)) return;
    _antPathTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => unawaited(_tickAntPath()),
    );
  }

  Future<void> _tickAntPath() async {
    final controller = _controller;
    if (controller == null || !_territoryLayersReady) return;
    _antPathStep = (_antPathStep + 1) % _antPathDashSequence.length;
    final dash = _antPathDashSequence[_antPathStep];
    await controller.setLayerProperties(
      _territoryOutlineLayerId,
      LineLayerProperties(
        lineDasharray: [
          'case',
          ['==', ['get', 'owner'], 'rival'],
          ['literal', dash],
          ['literal', [1, 0]],
        ],
      ),
    );
  }

  /// Squad territory heatmap (item 11) — an aggregated tinted overlay
  /// distinct from the individual owned/rival colors above, covering every
  /// territory owned by the caller or by an online squad member. Its own
  /// `GeoJsonSource`/`FillLayer`, added below the main territory fill layer
  /// (`belowLayerId`) so it reads as a low-opacity underlay rather than
  /// obscuring the per-member coloring on top of it — same intent as the
  /// old per-territory `Fill` annotations, just as one style layer whose
  /// source is refreshed via `setGeoJsonSource` and whose on/off toggle is
  /// `setLayerVisibility` instead of add/remove churn.
  Future<void> _redrawSquadHeatmap() async {
    final controller = _controller;
    if (controller == null || !mounted || !_styleReady) return;
    final semantic = context.semanticColors;
    final tint = Color.lerp(semantic.territoryOwned, Colors.white, 0.15)!;

    if (!_squadHeatmapLayerReady) {
      await controller.addGeoJsonSource(_squadHeatmapSourceId, const {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      });
      await controller.addFillLayer(
        _squadHeatmapSourceId,
        _squadHeatmapFillLayerId,
        FillLayerProperties(
          fillColor: _colorToHex(tint),
          fillOpacity: 0.22,
        ),
        belowLayerId: _territoryLayersReady ? _territoryFillLayerId : null,
      );
      _squadHeatmapLayerReady = true;
    }

    final features = [
      for (final territory in _lastTerritories)
        if (territory.isMine || _squadMemberIds.contains(territory.ownerId))
          TerritoryMapStyle.territoryToGeoJsonFeature(territory, const {}),
    ];
    await controller.setGeoJsonSource(_squadHeatmapSourceId, {
      'type': 'FeatureCollection',
      'features': features,
    });
    await controller.setLayerVisibility(
      _squadHeatmapFillLayerId,
      _showSquadHeatmap,
    );
  }

  /// Capture-density heatmap (item 4) — a `HeatmapLayerProperties` layer
  /// fed from `GetRecentTerritoryCaptures` (the same use case the Squad
  /// page's "conquest ticker" already uses — no duplicate RPC call added).
  /// Lazily adds the source/layer on first call (mirrors
  /// `_redrawSquadHeatmap`'s `_squadHeatmapLayerReady` guard), then just
  /// refreshes the source data and visibility on every later call (sheet
  /// toggle, periodic refetch).
  Future<void> _redrawCaptureHeatmap() async {
    final controller = _controller;
    if (controller == null || !mounted || !_styleReady) return;

    if (!_captureHeatmapLayerReady) {
      await controller.addGeoJsonSource(_captureHeatmapSourceId, const {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      });
      await controller.addHeatmapLayer(
        _captureHeatmapSourceId,
        _captureHeatmapLayerId,
        const HeatmapLayerProperties(
          heatmapRadius: 28,
          // Bigger captures contribute more weight, same
          // small-capture-still-visible/large-capture-caps-out reasoning as
          // the fill-extrusion height breakpoints above.
          heatmapWeight: [
            'interpolate',
            ['linear'],
            ['get', 'areaSqm'],
            0, 0.2,
            2500, 0.6,
            20000, 1.0,
          ],
          heatmapIntensity: 1,
          heatmapOpacity: 0.6,
        ),
        // Below the territory fill so captured-territory colors still read
        // clearly on top of the heatmap glow rather than getting washed out.
        belowLayerId: _territoryLayersReady ? _territoryFillLayerId : null,
      );
      _captureHeatmapLayerReady = true;
    }

    List<TerritoryCaptureFeedItem> captures;
    try {
      captures = await getIt<GetRecentTerritoryCaptures>()(rowLimit: 200);
    } catch (_) {
      // Best-effort — keep whatever was last drawn (or nothing, before the
      // first successful fetch).
      return;
    }
    if (!mounted || _controller == null) return;

    final features = [
      for (final capture in captures)
        if (capture.lat != null && capture.lng != null)
          {
            'type': 'Feature',
            'properties': {'areaSqm': capture.areaTakenSqm},
            'geometry': {
              'type': 'Point',
              'coordinates': [capture.lng, capture.lat],
            },
          },
    ];
    await controller.setGeoJsonSource(_captureHeatmapSourceId, {
      'type': 'FeatureCollection',
      'features': features,
    });
    await controller.setLayerVisibility(
      _captureHeatmapLayerId,
      _showCaptureHeatmap,
    );
  }

  /// Clustered squad-member location markers (item 5) — same clustered
  /// point-source structure `_drawBountyMarkers` above uses for bounty
  /// zones (`addSource` + `cluster: true` + unclustered/cluster-bubble/
  /// cluster-count layers), fed from the already-live
  /// `WatchSquadPresence` stream (`_loadSquadInfo`) rather than a new
  /// fetch. Only members with a non-null `lat`/`lng` (best-effort,
  /// self-asserted per `SquadPresenceMember`'s doc comment) are drawn.
  Future<void> _redrawSquadMemberMarkers() async {
    final controller = _controller;
    if (controller == null || !mounted || !_styleReady) return;
    final scheme = Theme.of(context).colorScheme;
    final blueHex = _colorToHex(scheme.secondary);

    final located = _squadPresenceMembers.where(
      (m) => m.lat != null && m.lng != null,
    );
    final collection = {
      'type': 'FeatureCollection',
      'features': [
        for (final member in located)
          {
            'type': 'Feature',
            'properties': {
              'id': member.userId,
              'displayName': member.displayName,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [member.lng, member.lat],
            },
          },
      ],
    };

    if (!_squadMemberMarkersLayerReady) {
      await controller.addSource(
        _squadMemberMarkersSourceId,
        GeojsonSourceProperties(
          data: collection,
          cluster: true,
          clusterRadius: 50,
          clusterMaxZoom: 14,
        ),
      );
      await controller.addCircleLayer(
        _squadMemberMarkersSourceId,
        _squadMemberUnclusteredLayerId,
        CircleLayerProperties(
          circleRadius: 8,
          circleColor: blueHex,
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
        filter: [
          '!',
          ['has', 'point_count'],
        ],
      );
      await controller.addCircleLayer(
        _squadMemberMarkersSourceId,
        _squadMemberClusterCircleLayerId,
        CircleLayerProperties(
          circleRadius: 16,
          circleColor: blueHex,
          circleOpacity: 0.85,
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
        filter: ['has', 'point_count'],
      );
      await controller.addSymbolLayer(
        _squadMemberMarkersSourceId,
        _squadMemberClusterCountLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'point_count_abbreviated'],
          textSize: 12,
          textColor: '#FFFFFF',
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        filter: ['has', 'point_count'],
      );
      _squadMemberMarkersLayerReady = true;
    } else {
      await controller.setGeoJsonSource(_squadMemberMarkersSourceId, collection);
    }
  }

  /// Monotonically-increasing request id — guards against an in-flight
  /// `refreshTerritories` call from a *previous* viewport completing after
  /// a *newer* one and overwriting its (more current) result. `onCameraIdle`
  /// can fire in quick succession (fling-then-settle, or rapid
  /// pan/zoom/pan), and network responses don't necessarily arrive in the
  /// order they were sent.
  int _refreshRequestId = 0;

  /// Debounces `onCameraIdle` so a rapid pan/zoom/pan sequence (each leg
  /// settling briefly before the next starts) fires one network request
  /// after the dust settles, not one per idle event. The stale-response
  /// guard above (`_refreshRequestId`) handles out-of-order *results*; this
  /// handles redundant *requests* in the first place.
  static const _bboxRefreshDebounce = Duration(milliseconds: 400);
  Timer? _bboxRefreshDebounceTimer;

  void _scheduleRefreshForCurrentView() {
    _bboxRefreshDebounceTimer?.cancel();
    _bboxRefreshDebounceTimer = Timer(_bboxRefreshDebounce, () {
      unawaited(_refreshForCurrentView());
    });
  }

  Future<void> _refreshForCurrentView() async {
    final controller = _controller;
    if (controller == null) return;
    final requestId = ++_refreshRequestId;
    final bounds = await controller.getVisibleRegion();
    if (requestId != _refreshRequestId) {
      return; // superseded while awaiting the region
    }

    await getIt<RefreshTerritories>()(
      GeoBounds(
        minLat: bounds.southwest.latitude,
        minLng: bounds.southwest.longitude,
        maxLat: bounds.northeast.latitude,
        maxLng: bounds.northeast.longitude,
      ),
    );
  }

  Future<void> _recenter() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(_center, _focusZoom),
    );
  }

  Future<void> _zoomIn() async {
    await _controller?.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    await _controller?.animateCamera(CameraUpdate.zoomOut());
  }

  /// "3D view" toggle (skyline redesign item 1) — animates camera `tilt`
  /// between 0 and 45deg via `CameraUpdate.newCameraPosition` (the only
  /// `CameraUpdate` factory that carries a `tilt`; `newLatLngZoom` always
  /// resets it to 0). Keeps the current center/zoom/bearing from
  /// `controller.cameraPosition` — falls back to `_center`/`_focusZoom` if
  /// the controller hasn't reported a camera position yet (shouldn't
  /// normally happen once the map's created, but cheaper than a null check
  /// at every call site).
  Future<void> _toggle3DView() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_is3D;
    setState(() => _is3D = next);
    final current = controller.cameraPosition;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: current?.target ?? _center,
          zoom: current?.zoom ?? _focusZoom,
          bearing: current?.bearing ?? 0,
          tilt: next ? 45 : 0,
        ),
      ),
    );
  }

  /// The zoom used to center on the user's own position — clamped to the
  /// active style tier's data ceiling (see `MapStyleLoader.dataMaxZoom`) so
  /// the bundled fallback tier doesn't overzoom into a single illegible
  /// blown-up tile fragment.
  double get _focusZoom => math.min(15, _styleLoader.dataMaxZoom ?? 15);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Bottom offset to sit closely above the floating bottom navigation bar
    final navBarOffset = bottomPadding + 36.0;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // Full-Bleed Edge-to-Edge Map Canvas
          Positioned.fill(
            // The map itself has no accessible representation of territory
            // data below this — it's only ever drawn as visual fills. This
            // gives a screen-reader user the same at-a-glance summary the
            // owned-area chip and rival/at-risk banners convey visually.
            child: Semantics(
              label:
                  '${_atRisk.length} '
                  '${_atRisk.length == 1 ? 'territory' : 'territories'} '
                  'undefended.'
                  '${_currentRival != null ? ' Recent rival activity nearby.' : ''}',
              child: MapLibreMap(
                key: _styleLoader.styleKey,
                styleString: _styleLoader.styleString,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(20, 0),
                  zoom: 2,
                ),
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                onCameraIdle: _scheduleRefreshForCurrentView,
                myLocationEnabled: false,
                logoEnabled: false,
                attributionButtonPosition: AttributionButtonPosition.bottomLeft,
                // Required for `controller.cameraPosition` to ever be
                // non-stale — without this, the plugin's own doc comment
                // says it stays permanently null (or, worse, permanently
                // equal to `initialCameraPosition`), which was silently
                // breaking `_toggle3DView`'s "preserve wherever the user
                // currently is, just add tilt" logic: every toggle jumped
                // the camera back to `initialCameraPosition`'s zoom-2 world
                // view instead of tilting in place. Found via live device
                // testing, not static analysis.
                trackCameraPosition: true,
              ),
            ),
          ),

          if (_styleLoader.status == MapStyleLoadStatus.retrying)
            MapStyleRetryingBanner(top: topPadding + 64),
          if (_styleLoader.status == MapStyleLoadStatus.failed)
            MapStyleFailureOverlay(onRetry: _styleLoader.retry),
          // Persistent — stays up for as long as the loader is on the
          // bundled fallback tier, unlike the retrying banner above (which
          // disappears the instant *any* tier, including this one, finishes
          // loading). See `MapStyleLoader.isDegradedFallback`'s doc comment.
          if (_styleLoader.isDegradedFallback)
            MapDegradedModeChip(top: topPadding + 64),

          // OSM Attribution
          Positioned(
            bottom: navBarOffset + 2,
            right: 8,
            child: const OsmAttribution(),
          ),

          // Top Floating Apple Glass Navigation Header & Status Banners
          Positioned(
            top: topPadding + 8,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppleGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Territory',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: scheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          _OwnedAreaChip(scheme: scheme),
                          const SizedBox(width: 8),
                          const CurrentUserAvatarButton(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TerritoryLegend(showRivalTerritory: _showRivalTerritory),
                  ],
                ),
                const _SyncStatusBanner(),
                if (_atRisk.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _AtRiskBanner(territories: _atRisk, scheme: scheme),
                ],
                if (_currentRival != null) ...[
                  const SizedBox(height: 8),
                  _RivalCard(rival: _currentRival!, scheme: scheme),
                ],
              ],
            ),
          ),

          // Bottom Floating Apple Glass Action Dock (Positioned closely above bottom nav bar)
          Positioned(
            bottom: navBarOffset + 6,
            left: 16,
            right: 16,
            child: Center(
              child: AppleGlassContainer(
                blurAmount: 25,
                padding: const EdgeInsets.all(6),
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundIconButton(
                      icon: Icons.my_location,
                      tooltip: 'Center map',
                      onTap: _recenter,
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ActiveRunPage(),
                          ),
                        );
                        if (!context.mounted) return;
                        await _locateSelf();
                        await _refreshForCurrentView();
                        unawaited(_loadRivalAndDecayStatus());
                      },
                      icon: const Icon(Icons.directions_run, size: 20),
                      label: const Text(
                        'CLAIM TERRITORY',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _RoundIconButton(
                      icon: _is3D ? Icons.view_in_ar : Icons.view_in_ar_outlined,
                      tooltip: _is3D ? 'Switch to 2D view' : 'Switch to 3D view',
                      onTap: _toggle3DView,
                    ),
                    const SizedBox(width: 6),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _RoundIconButton(
                          icon: Icons.layers,
                          tooltip: _showRivalTerritory
                              ? 'Map layers'
                              : 'Map layers (rival territory hidden)',
                          onTap: () => _showLayersSheet(context),
                        ),
                        if (!_showRivalTerritory)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: context.semanticColors.territoryRival,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.surfaceContainerHigh,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Zoom Controls (Right Floating Bar, positioned above Action Dock)
          Positioned(
            right: 16,
            bottom: navBarOffset + 64,
            child: _ZoomControls(
              scheme: scheme,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLayersSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E).withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.90),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.6),
                      width: 0.5,
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          Text(
                            'Map layers',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // `SwitchListTile` paints its background/ink
                          // splashes on the nearest `Material` ancestor —
                          // without this, the enclosing glass `Container`'s
                          // `DecoratedBox` swallows them and taps show no
                          // visual feedback at all.
                          Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Show rival territory',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                "Hide other players' captured land",
                                style: TextStyle(
                                  color: secondaryLabelColor(sheetContext),
                                ),
                              ),
                              value: _showRivalTerritory,
                              onChanged: (value) {
                                setSheetState(
                                  () => _showRivalTerritory = value,
                                );
                                setState(() => _showRivalTerritory = value);
                                unawaited(_redrawFills());
                              },
                            ),
                          ),
                          // Squad territory heatmap (item 11) — an
                          // aggregated overlay of every squad member's
                          // owned territory. Disabled with an explanatory
                          // subtitle rather than hidden entirely when the
                          // caller isn't in a squad, so the layer's
                          // existence isn't a surprise once they join one.
                          Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Squad territory heatmap',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                _mySquad == null
                                    ? 'Join a squad to highlight its combined turf'
                                    : "Highlight your squad's combined turf",
                                style: TextStyle(
                                  color: secondaryLabelColor(sheetContext),
                                ),
                              ),
                              value: _showSquadHeatmap,
                              onChanged: _mySquad == null
                                  ? null
                                  : (value) {
                                      setSheetState(
                                        () => _showSquadHeatmap = value,
                                      );
                                      setState(() => _showSquadHeatmap = value);
                                      unawaited(_redrawSquadHeatmap());
                                    },
                            ),
                          ),
                          // Capture-density heatmap (item 4) — recent
                          // captures across all users, not just this
                          // caller's squad, so (unlike the squad heatmap
                          // above) it's never gated on squad membership.
                          Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Capture activity heatmap',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Highlight where territory is changing hands',
                                style: TextStyle(
                                  color: secondaryLabelColor(sheetContext),
                                ),
                              ),
                              value: _showCaptureHeatmap,
                              onChanged: (value) {
                                setSheetState(
                                  () => _showCaptureHeatmap = value,
                                );
                                setState(() => _showCaptureHeatmap = value);
                                unawaited(_redrawCaptureHeatmap());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _colorToHex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2)}';
}

/// Surfaces `SyncWorker.status` — previously defined but never consumed by
/// any UI, so a stuck/failed sync (e.g. a captured run stuck in the local
/// outbox, never reaching the server) was completely invisible to the user.
/// Hidden on `idle` (nothing pending); `error` gets a manual retry button
/// rather than silently waiting on the next backoff/periodic drain.
class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<SyncStatus>(
      stream: getIt<SyncWorker>().status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || status == SyncStatus.idle) {
          return const SizedBox.shrink();
        }

        final (icon, label, bg, fg) = switch (status) {
          SyncStatus.syncing => (
            null,
            'Syncing…',
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
          ),
          SyncStatus.offline => (
            Icons.cloud_off,
            "Offline — will sync when you're back online",
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
          ),
          SyncStatus.error => (
            Icons.sync_problem,
            "Couldn't sync some changes",
            scheme.errorContainer,
            scheme.onErrorContainer,
          ),
          SyncStatus.idle => (null, '', scheme.surface, scheme.onSurface),
        };

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppleGlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderRadius: BorderRadius.circular(999),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == SyncStatus.syncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else
                  Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label, style: TextStyle(fontSize: 12, color: fg)),
                ),
                if (status == SyncStatus.error) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => unawaited(getIt<SyncWorker>().drainOutbox()),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OwnedAreaChip extends StatelessWidget {
  const _OwnedAreaChip({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: getIt<WatchOwnedArea>()(),
      builder: (context, snapshot) {
        final areaSqm = snapshot.data ?? 0;
        final label = '${(areaSqm / 1000000).toStringAsFixed(3)} km²';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield, size: 13, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TerritoryLegend extends StatelessWidget {
  const _TerritoryLegend({required this.showRivalTerritory});

  final bool showRivalTerritory;

  @override
  Widget build(BuildContext context) {
    // Single source of truth (item 2): reads the same
    // `context.semanticColors` roles the map's own fill/outline redraw
    // logic uses in `_TerritoryPageState._redrawFills`, instead of a
    // second, independently-hardcoded set of hex literals.
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: semantic.territoryOwned),
          const SizedBox(width: 6),
          Text(
            'YOU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: scheme.onSurface,
            ),
          ),
          if (showRivalTerritory) ...[
            const SizedBox(width: 12),
            // Dashed ring around the dot (rather than a plain solid dot)
            // mirrors the map's own dashed-outline cue for rival territory
            // (item 3) — colorblind users get the same secondary shape
            // signal in the legend as on the map itself.
            _LegendDot(color: semantic.territoryRival, dashed: true),
            const SizedBox(width: 6),
            Text(
              'RIVALS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: scheme.onSurface,
              ),
            ),
          ],
          const SizedBox(width: 12),
          _LegendDot(color: semantic.territoryNeutral, hollow: true),
          const SizedBox(width: 6),
          Text(
            'OPEN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AtRiskBanner extends StatelessWidget {
  const _AtRiskBanner({required this.territories, required this.scheme});

  final List<TerritoryAtRisk> territories;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final soonest = territories.reduce(
      (a, b) => a.expiresAt.isBefore(b.expiresAt) ? a : b,
    );
    final remaining = soonest.expiresAt.difference(DateTime.now());
    // Under 24h previously still read `.inDays` -> "0d", the most urgent
    // case reading as the least informative. Switch to hours below a day.
    final timeLeft = remaining.inDays >= 1
        ? '${remaining.inDays.clamp(0, 99)}d'
        : '${remaining.inHours.clamp(0, 23)}h';
    final label = territories.length == 1
        ? "1 territory undefended — reverts in $timeLeft"
        : "${territories.length} territories undefended — reverts in $timeLeft";
    // Same role the map's own pulsing at-risk border uses (item 5/2) —
    // this banner and the map polygon it's describing now share one color
    // source instead of two independently chosen "warning orange" hexes.
    final atRiskColor = context.semanticColors.territoryAtRisk;

    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      borderColor: atRiskColor.withValues(alpha: 0.6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: atRiskColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DEFEND TERRITORY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: atRiskColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RivalCard extends StatelessWidget {
  const _RivalCard({required this.rival, required this.scheme});

  final Rival rival;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final name = rival.rivalDisplayName ?? 'A rival';
    final areaLabel =
        '${(rival.areaTakenSqm / 1000000).toStringAsFixed(3)} km²';
    final isWinner = rival.asWinner;
    final accentColor = isWinner
        ? scheme.primary
        : context.semanticColors.territoryRival;
    final label = isWinner
        ? 'Captured $areaLabel from $name'
        : '$name seized $areaLabel from you';

    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      borderColor: accentColor.withValues(alpha: 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWinner ? Icons.emoji_events : Icons.sports_mma,
              size: 16,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isWinner ? 'VICTORY' : 'RIVAL ATTACK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: accentColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Only shown when the rival took land from the caller — a win
          // already reads as resolved and doesn't need a follow-up CTA.
          // `current_rival()` now carries the rival's territory centroid
          // (`Rival.territoryLat`/`territoryLng`, null if they currently own
          // no territory), so this opens `ActiveRunPage` focused there
          // instead of the default zoomed-out world view.
          if (!isWinner) ...[
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ActiveRunPage(
                    focusLocation: rival.territoryLat != null
                        ? LatLng(rival.territoryLat!, rival.territoryLng!)
                        : null,
                  ),
                ),
              ),
              child: const Text('Steal back'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    this.dashed = false,
    this.hollow = false,
  });

  final Color color;

  /// Ring instead of a filled dot, with a dashed-looking border — mirrors
  /// the map's dashed rival outline (item 3) as a shape cue, not just hue.
  final bool dashed;

  /// Outline-only, no fill — mirrors the neutral-zone ring style (item 4).
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    if (dashed || hollow) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: dashed ? 2 : 1.5),
        ),
      );
    }
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
            ),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.scheme,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final ColorScheme scheme;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return AppleGlassContainer(
      borderRadius: BorderRadius.circular(999),
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundIconButton(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onTap: onZoomIn,
          ),
          Container(
            width: 24,
            height: 0.5,
            color: scheme.outline.withValues(alpha: 0.3),
          ),
          _RoundIconButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onTap: onZoomOut,
          ),
        ],
      ),
    );
  }
}
