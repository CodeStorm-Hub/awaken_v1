import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, MissingPluginException, PlatformException;
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
import '../../domain/usecases/watch_territories.dart';
import '../widgets/map_style_loader.dart';
import '../widgets/map_style_overlays.dart';
import '../widgets/osm_attribution.dart';
import '../widgets/territory_hud_widgets.dart';
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
  const TerritoryPage({required this.isActive, super.key});

  /// True while this is the selected shell tab. The native `MapLibreMap`
  /// view is only ever built while this is true — see `_isMapActive`'s doc
  /// comment on why, and `_handleActiveChanged` for the teardown/rebuild
  /// mechanics.
  final ValueListenable<bool> isActive;

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  MapLibreMapController? _controller;
  StreamSubscription<List<Territory>>? _territoriesSub;
  List<Territory> _lastTerritories = const [];

  // Territory fill/outline rendering (items 2/3/5/6/7) runs entirely off one
  // `GeoJsonSource` + several style layers instead of per-territory
  // `Fill`/`Line` annotations — see this file's class doc comment.
  // `_territoryLayersReady` guards the one-time `addGeoJsonSource`/
  // `addLayer` calls; later redraws just call `setGeoJsonSource` on the
  // existing source. Rival territory's dashed outline (item 3) is a real
  // `line-dasharray` *literal* on its own filtered layer
  // (`_territoryOutlineRivalLayerId`, separate from
  // `_territoryOutlineOwnedLayerId`) — no more broken-segment faking
  // (compare the now-deleted `TerritoryMapStyle.ringToDashSegments`), and no
  // data-driven dasharray expression either, since MapLibre Native doesn't
  // support that for this property (see that layer's own creation comment).
  // The pulsing at-risk border (item 5) is a third, filtered outline layer
  // (`_territoryAtRiskOutlineLayerId`) whose `lineWidth`/`lineOpacity` are
  // ticked via `setLayerProperties` instead of re-adding `Line` annotations.
  static const _territorySourceId = 'territories-source';
  static const _territoryFillLayerId = 'territories-fill-layer';
  // Split into two feature-filtered layers rather than one layer with a
  // data-driven `line-dasharray` expression (`['case', ['==', ['get',
  // 'owner'], 'rival'], ...]`) — confirmed via the official MapLibre style
  // spec's SDK support table that `line-dasharray` never supports
  // data-driven styling on MapLibre Native Android/iOS (only MapLibre GL
  // JS does; tracked upstream as maplibre-native#744). That data expression
  // was being silently rejected on every single call — both the one-time
  // initial set below and every 80ms ant-path tick — confirmed live via
  // logcat's `[JNI]: Error setting property: line-dasharray data
  // expressions not supported`, spamming continuously (flutter_run_logs.md).
  // A layer-level `filter` (not a paint-property expression) IS supported,
  // so each layer here only ever contains one territory type and its
  // `lineDasharray` is always a plain `['literal', [...]]` — no data
  // expression, no rejection.
  static const _territoryOutlineOwnedLayerId =
      'territories-outline-owned-layer';
  static const _territoryOutlineRivalLayerId =
      'territories-outline-rival-layer';
  static const _territoryExtrusionLayerId = 'territories-extrusion-layer';
  // Rim-light/glow (territory map 3D redesign §5.2) — MapLibre has no
  // native glow/bloom paint property, so this fakes one the way comparable
  // implementations do: a wider, blurred (`lineBlur`), translucent
  // companion line per ownership type, inserted directly *below* its crisp
  // `_territoryOutline*LayerId` counterpart (added right after, in
  // `_redrawFills`) so the crisp line reads on top of a soft halo instead of
  // the halo swallowing it.
  static const _territoryGlowOwnedLayerId = 'territories-glow-owned-layer';
  static const _territoryGlowRivalLayerId = 'territories-glow-rival-layer';
  // Hollow perimeter "wall" — a separate GeoJSON source of frame/annulus
  // MultiPolygons (`TerritoryMapStyle.territoryToWallGeoJsonFeature`), so the
  // 3D fill-extrusion layer can render a wall along just the border instead
  // of a solid block over the whole captured area (which, on live-device
  // review, both looked like a huge plain slab and completely hid the
  // streets/buildings underneath — the opposite of what §5.1's city
  // buildings were for).
  static const _territoryWallSourceId = 'territories-wall-source';
  static const _territoryAtRiskOutlineLayerId =
      'territories-atrisk-outline-layer';
  // "Front line" (proximity-based, distinct from the decay-based at-risk
  // border above) — a third outline layer, filtered to owned territories
  // within `_contestedRadiusM` of any rival territory's centroid (see
  // `_redrawFills`'s `contested` computation). Reads as "actively contested
  // edge" versus "deep rival territory," which previously looked identical.
  static const _territoryContestedOutlineLayerId =
      'territories-contested-outline-layer';
  static const _contestedRadiusM = 250.0;
  bool _territoryLayersReady = false;
  String? _lastFillsFingerprint;

  // Territory "flags" — a point `SymbolLayer` (Conquest Skyline redesign)
  // planting a small tinted flag glyph at each visible territory's
  // approximate centroid, on top of the fill/extrusion/outline layers.
  // Ownership reads instantly at any zoom this way, even before the 3D
  // extrusion is perceptible. Own GeoJSON source (points, not the polygon
  // geometry the other territory layers share) since `SymbolLayer` needs
  // point features.
  static const _flagsSourceId = 'territory-flags-source';
  static const _flagsSymbolLayerId = 'territory-flags-layer';
  bool _flagsLayerReady = false;

  /// Guards the one-time `controller.addImage` call registering
  /// [TerritoryMapStyle.flagIconName] — a style/native-view property, so
  /// (like `_territoryLayersReady` etc.) it must be re-registered after a
  /// fallback-tier style swap tears down and recreates the native view.
  bool _flagIconRegistered = false;

  /// Guards the one-time `controller.addImage` call registering the "3D
  /// puck" current-position avatar (`TerritoryMapStyle.
  /// generateAvatarPuckIconBytes`/`avatarPuckIconNamePrefix`) — same
  /// per-native-view lifecycle as `_flagIconRegistered`.
  bool _avatarIconRegistered = false;

  /// Current camera zoom, tracked via `controller.cameraPosition` on every
  /// `onCameraIdle` (see `_refreshForCurrentView`) — drives the "SKYLINE
  /// MODE" HUD chip, which should only appear once the city-buildings layer
  /// (`minzoom: 14`) is actually rendering something.
  double? _currentZoom;

  /// True from the first `onCameraMove` of a gesture until the next
  /// `onCameraIdle` — lets `_tickPulse`/`_tickAntPath` skip their
  /// `setLayerProperties` platform-channel calls while the user is actively
  /// panning/zooming. Those two tickers run on their own timers regardless
  /// of camera state (120-160ms/80-100ms), so without this they keep firing
  /// method-channel round trips throughout a drag/pinch gesture, competing
  /// with the native view's own pan/zoom rendering for main-thread work —
  /// exactly when frame drops are most visible. Never triggers a rebuild
  /// (no `setState`) — read only by the two tick methods.
  bool _cameraMoving = false;

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

  /// "3D view" toggle. Territory map 3D redesign §5.3: 3D is now the
  /// *default* visual language (starts `true`) rather than a hidden opt-in —
  /// the button is repurposed as a "look straight down" escape hatch for
  /// navigation, not the primary way to discover the skyline. Still just
  /// animates camera `tilt` between 0 and 45deg.
  bool _is3D = true;
  Timer? _pulseTimer;
  double _pulseT = 0;

  /// Animated "ant path" dashed rival outline — steps
  /// `_territoryOutlineRivalLayerId`'s `line-dasharray` through
  /// [_antPathDashSequence] on a timer, same structural pattern as
  /// `_pulseTimer`/`_tickPulse` above (including the reduce-motion guard in
  /// `_updateAntPathTimer`, mirroring `_updatePulseTimer`'s
  /// `hasAtRisk`-gating). Owned territories are a separate layer
  /// (`_territoryOutlineOwnedLayerId`) with no `lineDasharray` at all
  /// (always solid) — see that layer's own creation comment for why a
  /// single shared layer with a data-driven dasharray doesn't work on
  /// native Android/iOS.
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
  static const _bountyClusterCircleLayerId =
      'bounty-zones-cluster-circle-layer';
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
    _isMapActive = widget.isActive.value;
    widget.isActive.addListener(_handleActiveChanged);
    // Data loading (location, rival/decay status, squad membership) starts
    // regardless of `_isMapActive` — cheap, and keeps state fresh for
    // whenever the map itself first gets built. Only the native map view
    // construction in `build()` is gated on tab visibility.
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

  /// True only while this tab is the shell's selected tab — gates whether
  /// `build()` constructs the native `MapLibreMap` widget at all. MapLibre's
  /// own render thread has no concept of Flutter's `IndexedStack`-based
  /// hiding, so simply being visually obscured/offstage does not stop it
  /// from continuing to composite frames — confirmed live via DevTools
  /// (Raster-thread-bound jank, and a flat ~20fps of continuous frame
  /// production sitting idle on a different tab). Not building the widget at
  /// all when inactive tears down the underlying platform view/render
  /// thread the same way a `MapStyleLoader` fallback-tier swap already
  /// does — `_onMapCreated`'s existing reset logic (every layer-ready flag
  /// back to false) already handles "a completely fresh native view"
  /// generically, so re-activating needs no special-cased setup beyond that
  /// already-correct path.
  late bool _isMapActive;

  void _handleActiveChanged() {
    if (!mounted) return;
    final active = widget.isActive.value;
    setState(() {
      _isMapActive = active;
      if (!active) {
        // Mirrors `_onMapCreated`'s reset — the controller/timers are about
        // to belong to a view `build()` is no longer going to construct.
        _pulseTimer?.cancel();
        _pulseTimer = null;
        _antPathTimer?.cancel();
        _antPathTimer = null;
        _bboxRefreshDebounceTimer?.cancel();
        _controller = null;
        _styleReady = false;
        _territoryLayersReady = false;
      }
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
    widget.isActive.removeListener(_handleActiveChanged);
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
      final squadChanged = _mySquad?.id != squad?.id;
      _mySquad = squad;
      // Only the legend text ("Join a squad to highlight its combined
      // turf") reads `_mySquad` from the widget tree, and only when squad
      // membership itself changes — not on every presence tick below. A
      // targeted `setState` here (instead of one on every presence
      // emission) keeps that text in sync without paying for a full-page
      // rebuild (incl. two `BackdropFilter` blurs) every ~3s.
      if (squadChanged && mounted) setState(() {});
      if (squad == null) {
        _squadMemberIds = {};
        _squadPresenceMembers = const [];
        unawaited(_redrawSquadHeatmap());
        unawaited(_redrawSquadMemberMarkers());
        return;
      }
      _presenceSub = getIt<WatchSquadPresence>()(squad.id).listen((members) {
        if (!mounted) return;
        // `_squadMemberIds`/`_squadPresenceMembers` are only ever read from
        // imperative map-redraw helpers (`_redrawFills`, `_redrawFlags`,
        // `_redrawSquadHeatmap`, `_redrawSquadMemberMarkers`), never from
        // this widget's `build()` — so a plain field assignment (no
        // `setState`) is correct here, not a shortcut. `WatchSquadPresence`
        // fires as often as every ~3s per active squadmate
        // (`SquadRepositoryImpl._broadcastThrottle`); wrapping this in
        // `setState` previously forced a full-page rebuild — including two
        // `AppleGlassContainer`/`BackdropFilter` blur repaints — on every
        // tick, which was the dominant cause of jank on this screen.
        _squadMemberIds = members.map((m) => m.userId).toSet();
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
        await controller.animateCamera(_cameraUpdateForFocus());
        await _syncCurrentPositionMarker();
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

  /// "3D puck" avatar (replaces the old flat `Circle` dot) — a `Symbol`
  /// annotation using `TerritoryMapStyle.avatarPuckIconNamePrefix`, a
  /// runtime-rendered icon baked with the theme's `primary` color (see
  /// `_avatarIconRegistered`).
  Symbol? _positionMarker;

  Future<void> _syncCurrentPositionMarker() async {
    final controller = _controller;
    if (controller == null || !_hasFix || !_avatarIconRegistered) return;
    if (_positionMarker == null) {
      _positionMarker = await controller.addSymbol(
        SymbolOptions(
          geometry: _center,
          iconImage: TerritoryMapStyle.avatarPuckIconNamePrefix,
          iconSize: 0.34,
          iconAnchor: 'center',
        ),
      );
    } else {
      await controller.updateSymbol(
        _positionMarker!,
        SymbolOptions(geometry: _center),
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
    _lastFillsFingerprint = null;
    _squadHeatmapLayerReady = false;
    _bountyMarkersLayerReady = false;
    _captureHeatmapLayerReady = false;
    _squadMemberMarkersLayerReady = false;
    _flagsLayerReady = false;
    _flagIconRegistered = false;
    _avatarIconRegistered = false;
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
      final isDark = mounted && Theme.of(context).brightness == Brightness.dark;
      final primaryColor = Theme.of(context).colorScheme.primary;
      unawaited(TerritoryBasemapRecolor.apply(controller, isDark: isDark));
      // Real 3D city buildings (§5.1) — skipped on the bundled offline
      // fallback tier, which is a minimal low-zoom (z0-6) extract with no
      // `building` source-layer at all (see `TerritoryMapStyle`'s doc
      // comment).
      if (!_styleLoader.isDegradedFallback) {
        unawaited(
          TerritoryBasemapRecolor.applyCityBuildings(
            controller,
            isDark: isDark,
          ),
        );
      }
      if (!_flagIconRegistered) {
        try {
          final bytes = await TerritoryMapStyle.generateFlagIconBytes();
          await controller.addImage(
            TerritoryMapStyle.flagIconName,
            bytes,
            true,
          );
          _flagIconRegistered = true;
        } catch (_) {
          // Best-effort — a missing flag icon just means territories render
          // without the marker (fill/extrusion/outline are unaffected).
        }
      }
      if (!_avatarIconRegistered) {
        try {
          final bytes = await TerritoryMapStyle.generateAvatarPuckIconBytes(
            color: primaryColor,
          );
          await controller.addImage(
            TerritoryMapStyle.avatarPuckIconNamePrefix,
            bytes,
          );
          _avatarIconRegistered = true;
        } catch (_) {
          // Best-effort — a missing avatar icon just means the position
          // marker doesn't (re)appear until the next successful style load.
        }
      }
    }
    if (_hasFix) {
      await _controller?.animateCamera(_cameraUpdateForFocus());
      await _syncCurrentPositionMarker();
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
          // Both OpenFreeMap base styles only host Noto Sans glyphs — an
          // omitted `textFont` sends an explicit null that the native SDK
          // fills with its own default (`Open Sans Regular, Arial Unicode
          // MS Regular`), which OpenFreeMap doesn't serve at all (confirmed
          // 404 in live logcat output). See `TerritoryBasemapRecolor`'s
          // `_notoSansRegular` doc comment for the full explanation.
          textFont: ['Noto Sans Regular'],
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

    // Materialized once (not left as a lazy `Iterable`)
    final visible = _lastTerritories
        .where((t) => t.isMine || _showRivalTerritory)
        .toList(growable: false);

    final fingerprint = visible
        .map(
          (t) =>
              '${t.id}_${t.isMine}_${t.health}_${t.ownerId}_${atRiskById.containsKey(t.id)}',
        )
        .join(';');
    if (_territoryLayersReady && fingerprint == _lastFillsFingerprint) {
      return;
    }

    final healthMap = <String, double>{
      for (final t in visible)
        if (t.isMine && t.health == null)
          t.id: _healthOf(t.id, atRiskById),
    };

    final params = TerritoryGeoJsonParams(
      visible: visible,
      atRiskIds: atRiskById.keys.toSet(),
      healthOfMap: healthMap,
      squadMemberIds: _squadMemberIds,
      ownedFillHex: _colorToHex(semantic.territoryOwnedFill),
      squadmateFillHex: _colorToHex(semantic.territorySquadmate),
      rivalFillHex: _colorToHex(semantic.territoryRivalFill),
      ownedOutlineHex: _colorToHex(semantic.territoryOwned),
      rivalOutlineHex: _colorToHex(semantic.territoryRival),
      ownedExtrusionHex: _colorToHex(semantic.territoryOwnedExtrusion),
      squadmateExtrusionHex: _colorToHex(semantic.territorySquadmateExtrusion),
      rivalExtrusionHex: _colorToHex(semantic.territoryRivalExtrusion),
      contestedRadiusM: _contestedRadiusM,
    );

    // Offload GeoJSON building + polygon insets + haversine distance checks to worker isolate via compute()
    final payload = visible.length > 5
        ? await compute(buildTerritoryGeoJsonPayload, params)
        : buildTerritoryGeoJsonPayload(params);

    if (!mounted || _controller == null) return;

    if (!_territoryLayersReady) {
      await controller.addGeoJsonSource(_territorySourceId, payload.mainCollection);
      await controller.addFillLayer(
        _territorySourceId,
        _territoryFillLayerId,
        const FillLayerProperties(
          fillColor: ['get', 'fillColor'],
          fillOpacity: ['get', 'fillOpacity'],
          fillOutlineColor: ['get', 'outlineColor'],
        ),
      );
      await controller.addGeoJsonSource(_territoryWallSourceId, payload.wallCollection);
      await controller.addFillExtrusionLayer(
        _territoryWallSourceId,
        _territoryExtrusionLayerId,
        const FillExtrusionLayerProperties(
          fillExtrusionColor: ['get', 'extrusionColor'],
          fillExtrusionOpacity: 0.92,
          fillExtrusionVerticalGradient: true,
          fillExtrusionBase: 0.0,
          fillExtrusionHeight: [
            'interpolate',
            ['linear'],
            ['get', 'areaSqm'],
            0,
            0,
            1,
            2,
            250,
            5,
            1000,
            8,
            2500,
            11,
            20000,
            16,
          ],
        ),
      );
      await controller.addLineLayer(
        _territorySourceId,
        _territoryGlowOwnedLayerId,
        const LineLayerProperties(
          lineColor: ['get', 'outlineColor'],
          lineWidth: 9,
          lineBlur: 6,
          lineOpacity: 0.55,
        ),
        filter: [
          '==',
          ['get', 'owner'],
          'me',
        ],
      );
      await controller.addLineLayer(
        _territorySourceId,
        _territoryGlowRivalLayerId,
        const LineLayerProperties(
          lineColor: ['get', 'outlineColor'],
          lineWidth: 9,
          lineBlur: 6,
          lineOpacity: 0.45,
        ),
        filter: [
          '==',
          ['get', 'owner'],
          'rival',
        ],
      );
      await controller.addLineLayer(
        _territorySourceId,
        _territoryOutlineOwnedLayerId,
        const LineLayerProperties(
          lineColor: ['get', 'outlineColor'],
          lineWidth: 2,
        ),
        filter: [
          '==',
          ['get', 'owner'],
          'me',
        ],
      );
      await controller.addLineLayer(
        _territorySourceId,
        _territoryOutlineRivalLayerId,
        LineLayerProperties(
          lineColor: const ['get', 'outlineColor'],
          lineWidth: 2,
          lineDasharray: ['literal', _antPathDashSequence.first],
        ),
        filter: [
          '==',
          ['get', 'owner'],
          'rival',
        ],
      );
      await controller.addLineLayer(
        _territorySourceId,
        _territoryAtRiskOutlineLayerId,
        LineLayerProperties(
          lineColor: _colorToHex(semantic.territoryAtRisk),
          lineWidth: 3,
          lineOpacity: 1.0,
        ),
        filter: [
          '==',
          ['get', 'atRisk'],
          true,
        ],
      );
      await controller.addLineLayer(
        _territorySourceId,
        _territoryContestedOutlineLayerId,
        LineLayerProperties(
          lineColor: _colorToHex(semantic.territoryContested),
          lineWidth: 3,
          lineOpacity: 1.0,
        ),
        filter: [
          '==',
          ['get', 'contested'],
          true,
        ],
      );
      _territoryLayersReady = true;
    } else {
      await controller.setGeoJsonSource(_territorySourceId, payload.mainCollection);
      await controller.setGeoJsonSource(_territoryWallSourceId, payload.wallCollection);
    }
    _lastFillsFingerprint = fingerprint;

    _updatePulseTimer(payload.hasAtRisk || payload.hasContested);
    _updateAntPathTimer(payload.hasRival);

    unawaited(_redrawFlagsWithCollection(payload.flagsCollection));

    if (newlyCaptured.isNotEmpty) {
      unawaited(_animateCaptureGrowIn(newlyCaptured));
    }
  }

  Future<void> _redrawFlagsWithCollection(Map<String, dynamic> collection) async {
    final controller = _controller;
    if (controller == null || !mounted || !_flagIconRegistered) return;

    if (!_flagsLayerReady) {
      await controller.addGeoJsonSource(_flagsSourceId, collection);
      await controller.addSymbolLayer(
        _flagsSourceId,
        _flagsSymbolLayerId,
        const SymbolLayerProperties(
          iconImage: TerritoryMapStyle.flagIconName,
          iconColor: ['get', 'flagColor'],
          iconSize: [
            'interpolate',
            ['linear'],
            ['zoom'],
            12,
            0.22,
            16,
            0.45,
            19,
            0.7,
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'bottom',
        ),
      );
      _flagsLayerReady = true;
    } else {
      await controller.setGeoJsonSource(_flagsSourceId, collection);
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
            [
              'in',
              ['get', 'id'],
              ['literal', idsList],
            ],
            [
              '*',
              ['get', 'fillOpacity'],
              fraction,
            ],
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
    // 120ms -> 160ms: halves this ticker's platform-channel call rate
    // (two `setLayerProperties` calls/tick) with no visible change to a
    // slow sine-wave pulse — cheap mitigation for sustained method-channel
    // traffic when this overlaps with the ant-path ticker below.
    _pulseTimer = Timer.periodic(
      const Duration(milliseconds: 280),
      (_) => unawaited(_tickPulse()),
    );
  }

  Future<void> _tickPulse() async {
    final controller = _controller;
    if (controller == null ||
        !mounted ||
        !_styleReady ||
        !_territoryLayersReady ||
        _cameraMoving) {
      return;
    }
    _pulseT += 0.12;
    final t = (math.sin(_pulseT * math.pi) + 1) / 2; // 0..1..0 loop
    final width = 2.0 + t * 3.0;
    final opacity = 0.5 + t * 0.5;
    try {
      await controller.setLayerProperties(
        _territoryAtRiskOutlineLayerId,
        LineLayerProperties(lineWidth: width, lineOpacity: opacity),
      );
      // Same pulse drives the "front line" contested border too — one
      // ticker, two independently-filtered layers (see `_updatePulseTimer`'s
      // call site, gated on `hasAtRisk || hasContested`). A no-op paint
      // update on a layer whose filter currently matches nothing is
      // harmless.
      await controller.setLayerProperties(
        _territoryContestedOutlineLayerId,
        LineLayerProperties(lineWidth: width, lineOpacity: opacity),
      );
    } on PlatformException {
      // The guard above is a synchronous snapshot — the map/style can still
      // be torn down (new key, teardown-and-recreate per the maplibre_gl
      // style-swap note) while this tick's platform-channel round trip is
      // in flight. Found live: an in-flight tick raced a map recreation and
      // threw `STYLE_NOT_READY` as an unhandled exception. Purely
      // cosmetic/decorative ticker — skipping a frame of the pulse
      // animation is harmless, no telemetry needed.
    } on MissingPluginException {
      // Same race as above, but for the case where the native platform view
      // itself was already disposed by the time the call reached it.
    }
  }

  /// Starts/stops the periodic `setLayerProperties` ticker driving the
  /// rival "ant path" dashed outline (item 3) — same
  /// gate/reduce-motion-guard structure as `_updatePulseTimer` above. A
  /// static (non-animated) dashed rival outline is drawn regardless either
  /// way — `_territoryOutlineRivalLayerId`'s `lineDasharray` is initialized
  /// to `_antPathDashSequence.first` when the layer is created and simply
  /// never gets ticked further under reduce-motion — so reduce-motion users
  /// still get the dashed-vs-solid ownership cue, just not the marching
  /// animation.
  void _updateAntPathTimer(bool hasRival) {
    if (!hasRival) {
      _antPathTimer?.cancel();
      _antPathTimer = null;
      return;
    }
    if (_antPathTimer != null) return;
    if (mounted && MediaQuery.disableAnimationsOf(context)) return;
    // 80ms -> 100ms: same rationale as `_updatePulseTimer` above — still
    // reads as a smooth marching-ants animation, less sustained
    // method-channel traffic.
    _antPathTimer = Timer.periodic(
      const Duration(milliseconds: 220),
      (_) => unawaited(_tickAntPath()),
    );
  }

  Future<void> _tickAntPath() async {
    final controller = _controller;
    if (controller == null ||
        !mounted ||
        !_styleReady ||
        !_territoryLayersReady ||
        _cameraMoving) {
      return;
    }
    _antPathStep = (_antPathStep + 1) % _antPathDashSequence.length;
    final dash = _antPathDashSequence[_antPathStep];
    try {
      // Plain literal array, no `case`/`get` — this layer (filtered to
      // `owner == 'rival'` at creation) only ever contains rival features,
      // so there's no per-feature branching left to express. See the
      // field-level comment on `_territoryOutlineRivalLayerId` for why a
      // data expression here would silently fail on native Android/iOS.
      await controller.setLayerProperties(
        _territoryOutlineRivalLayerId,
        LineLayerProperties(lineDasharray: ['literal', dash]),
      );
    } on PlatformException {
      // See `_tickPulse`'s catch clause — same in-flight-tick-races-a-map-
      // recreation race, confirmed live (`STYLE_NOT_READY`). Cosmetic
      // ticker, safe to skip a frame.
    } on MissingPluginException {
      // Same race, native platform view already disposed.
    }
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
    if (!_showSquadHeatmap && !_squadHeatmapLayerReady) return;
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
        FillLayerProperties(fillColor: _colorToHex(tint), fillOpacity: 0.22),
        belowLayerId: _territoryLayersReady ? _territoryFillLayerId : null,
      );
      _squadHeatmapLayerReady = true;
    }

    await controller.setLayerVisibility(
      _squadHeatmapFillLayerId,
      _showSquadHeatmap,
    );

    if (!_showSquadHeatmap) return;

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
    if (!_showCaptureHeatmap && !_captureHeatmapLayerReady) return;

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
          heatmapWeight: [
            'interpolate',
            ['linear'],
            ['get', 'areaSqm'],
            0,
            0.2,
            2500,
            0.6,
            20000,
            1.0,
          ],
          heatmapIntensity: 1,
          heatmapOpacity: 0.6,
        ),
        belowLayerId: _territoryLayersReady ? _territoryFillLayerId : null,
      );
      _captureHeatmapLayerReady = true;
    }

    await controller.setLayerVisibility(
      _captureHeatmapLayerId,
      _showCaptureHeatmap,
    );

    if (!_showCaptureHeatmap) return;

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
          // See the bounty cluster-count layer's identical comment above —
          // same fix, same reason (OpenFreeMap only hosts Noto Sans).
          textFont: ['Noto Sans Regular'],
        ),
        filter: ['has', 'point_count'],
      );
      _squadMemberMarkersLayerReady = true;
    } else {
      await controller.setGeoJsonSource(
        _squadMemberMarkersSourceId,
        collection,
      );
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

    // Altitude-gated "SKYLINE MODE" HUD chip (§6) — piggybacks on this
    // existing `onCameraIdle`-debounced call rather than a second listener,
    // since both need "settle after the camera stops moving."
    final zoom = controller.cameraPosition?.zoom;
    if (zoom != null && mounted && zoom != _currentZoom) {
      setState(() => _currentZoom = zoom);
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
    await controller.animateCamera(_cameraUpdateForFocus());
  }

  /// `CameraUpdate.newLatLngZoom` always resets `tilt` to 0 — it's the only
  /// factory that doesn't carry one. Since 3D is now the default view (§5.3),
  /// every "center/recenter on `_center`" call site needs to preserve the
  /// current `_is3D` tilt instead of silently flattening the camera back to
  /// top-down.
  CameraUpdate _cameraUpdateForFocus() => CameraUpdate.newCameraPosition(
    CameraPosition(target: _center, zoom: _focusZoom, tilt: _is3D ? 45 : 0),
  );

  /// Tap-to-inspect (Conquest Skyline redesign) — the map was previously
  /// purely decorative once territories rendered: nothing responded to a
  /// tap. `queryRenderedFeatures` (not `onFeatureTapped`/feature-state,
  /// which the plugin's own example app documents as web-only) works
  /// cross-platform on Android/iOS, so this queries the territory
  /// fill/extrusion layers at the tapped screen point and, if it hit one,
  /// looks the territory back up by the `id` property `_territoryFeatureProperties`
  /// already stamps onto every feature.
  Future<void> _onMapTapped(
    math.Point<double> point,
    LatLng coordinates,
  ) async {
    final controller = _controller;
    if (controller == null || !_territoryLayersReady) return;
    List<dynamic> features;
    try {
      features = await controller.queryRenderedFeatures(point, [
        _territoryFillLayerId,
        _territoryExtrusionLayerId,
      ], null);
    } catch (_) {
      return; // best-effort — a failed query just means the tap is a no-op
    }
    if (features.isEmpty) return;
    final rawProperties = (features.first as Map)['properties'];
    final id = rawProperties is Map ? rawProperties['id']?.toString() : null;
    if (id == null) return;

    Territory? tapped;
    for (final territory in _lastTerritories) {
      if (territory.id == id) {
        tapped = territory;
        break;
      }
    }
    if (tapped == null || !mounted) return;
    unawaited(_showTerritoryInspectSheet(tapped));
  }

  Future<void> _onMapLongTapped(
    math.Point<double> point,
    LatLng coordinates,
  ) async {
    unawaited(HapticFeedback.mediumImpact());
    await _onMapTapped(point, coordinates);
  }

  Future<void> _showTerritoryInspectSheet(Territory territory) async {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final isSquadmate =
        !territory.isMine && _squadMemberIds.contains(territory.ownerId);

    String? squadmateName;
    if (isSquadmate) {
      for (final member in _squadPresenceMembers) {
        if (member.userId == territory.ownerId) {
          squadmateName = member.displayName;
          break;
        }
      }
    }
    final ownerLabel = territory.isMine
        ? 'You'
        : (squadmateName ?? (isSquadmate ? 'Squadmate' : 'Rival'));
    final ownerColor = territory.isMine
        ? semantic.territoryOwned
        : isSquadmate
        ? semantic.territorySquadmate
        : semantic.territoryRival;
    final areaLabel = '${(territory.areaSqm / 1000000).toStringAsFixed(3)} km²';
    final atRiskById = {for (final t in _atRisk) t.id: t};
    final health = territory.isMine
        ? (territory.health?.toDouble() ?? _healthOf(territory.id, atRiskById))
        : null;
    final centroid = TerritoryMapStyle.territoryCentroid(territory);
    final canStealBack = !territory.isMine && !isSquadmate;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.brightness == Brightness.dark
                ? const Color(0xFF1C1C1E)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
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
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: ownerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ownerLabel,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        areaLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (health != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${health.round()}% defended',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (health / 100).clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: health < 30
                                ? semantic.territoryAtRisk
                                : semantic.territoryOwned,
                          ),
                        ),
                      ],
                      if (canStealBack) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: semantic.territoryRival,
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ActiveRunPage(
                                    focusLocation: LatLng(
                                      centroid.latitude,
                                      centroid.longitude,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.directions_run),
                            label: const Text('Steal back'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

  Future<void> _zoomIn() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.easeCamera(
      CameraUpdate.zoomIn(),
      duration: const Duration(milliseconds: 300),
      interpolation: CameraAnimationInterpolation.easeOut,
    );
  }

  Future<void> _zoomOut() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.easeCamera(
      CameraUpdate.zoomOut(),
      duration: const Duration(milliseconds: 300),
      interpolation: CameraAnimationInterpolation.easeOut,
    );
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
    final bounds = await controller.getVisibleRegion();
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
    final currentZoom = controller.cameraPosition?.zoom ?? _currentZoom ?? _focusZoom;
    await controller.easeCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: center,
          zoom: currentZoom,
          bearing: controller.cameraPosition?.bearing ?? 0,
          tilt: next ? 45 : 0,
        ),
      ),
      duration: const Duration(milliseconds: 300),
      interpolation: CameraAnimationInterpolation.easeOut,
    );
  }

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
              child: !_isMapActive
                  ? ColoredBox(color: scheme.surface)
                  : RepaintBoundary(
                      child: MapLibreMap(
                        key: _styleLoader.styleKey,
                        styleString: _styleLoader.styleString,
                        // Tilted from the very first frame (§5.3: 3D is the default
                        // visual language, not a hidden toggle) — `_locateSelf`/
                        // `_onStyleLoaded` re-apply this same tilt once a real GPS
                        // fix/style load lands, via `_cameraUpdateForFocus`.
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(20, 0),
                          zoom: 2,
                          tilt: 45,
                        ),
                        onMapCreated: _onMapCreated,
                        onStyleLoadedCallback: _onStyleLoaded,
                        onCameraMove: (_) {
                          if (!_cameraMoving) _cameraMoving = true;
                        },
                        onCameraIdle: () {
                          _cameraMoving = false;
                          _scheduleRefreshForCurrentView();
                        },
                        onMapClick: _onMapTapped,
                        onMapLongClick: _onMapLongTapped,
                        compassEnabled: false,
                        annotationConsumeTapEvents: const [AnnotationType.symbol],
                        featureTapsTriggersMapClick: true,
                        myLocationEnabled: false,
                        logoEnabled: false,
                        attributionButtonPosition:
                            AttributionButtonPosition.bottomLeft,
                        trackCameraPosition: false,
                      ),
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
            child: RepaintBoundary(
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
                            OwnedAreaChip(scheme: scheme),
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
                      TerritoryLegend(showRivalTerritory: _showRivalTerritory),
                      if (_is3D && (_currentZoom ?? 0) >= 14) ...[
                        const SizedBox(width: 8),
                        const SkylineModeChip(),
                      ],
                    ],
                  ),
                  const SyncStatusBanner(),
                  if (_atRisk.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AtRiskBanner(territories: _atRisk, scheme: scheme),
                  ],
                  if (_currentRival != null) ...[
                    const SizedBox(height: 8),
                    RivalCard(rival: _currentRival!, scheme: scheme),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Floating Apple Glass Action Dock (Positioned closely above bottom nav bar)
          Positioned(
            bottom: navBarOffset + 6,
            left: 16,
            right: 16,
            child: RepaintBoundary(
              child: Center(
              child: AppleGlassContainer(
                blurAmount: 25,
                padding: const EdgeInsets.all(6),
                borderRadius: BorderRadius.circular(999),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoundIconButton(
                        icon: Icons.my_location,
                        tooltip: 'Center map',
                        onTap: _recenter,
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
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
                      const SizedBox(width: 4),
                      RoundIconButton(
                        icon: _is3D
                            ? Icons.view_in_ar
                            : Icons.view_in_ar_outlined,
                        tooltip: _is3D
                            ? 'Switch to 2D view'
                            : 'Switch to 3D view',
                        onTap: _toggle3DView,
                      ),
                      const SizedBox(width: 4),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          RoundIconButton(
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
          ),
        ),

          // Zoom Controls (Right Floating Bar, positioned above Action Dock)
          Positioned(
            right: 16,
            bottom: navBarOffset + 64,
            child: ZoomControls(
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
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
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
