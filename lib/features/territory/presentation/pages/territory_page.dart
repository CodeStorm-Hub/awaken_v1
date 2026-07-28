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
/// territory polygons/markers are synced onto it *imperatively* via the
/// controller (`addFill`/`removeFills`) so the native map view is never
/// torn down and re-created — that rebuild-on-every-change pattern was the
/// direct cause of this page's earlier map/GPS-page choppiness.
class TerritoryPage extends StatefulWidget {
  const TerritoryPage({super.key});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  MapLibreMapController? _controller;
  StreamSubscription<List<Territory>>? _territoriesSub;
  final _fillsByTerritoryId = <String, List<Fill>>{};
  List<Territory> _lastTerritories = const [];

  // Dashed rival outlines (item 3) and pulsing at-risk borders (item 5) are
  // both built from separate `Line` annotations layered on top of each
  // territory's `Fill` — see `TerritoryMapStyle.ringToDashSegments`'s doc
  // comment for why (this `maplibre_gl` version has no line-dash paint
  // property to draw them as part of the fill's own outline).
  final _outlineLinesByTerritoryId = <String, List<Line>>{};
  final _atRiskPulseLinesByTerritoryId = <String, List<Line>>{};
  Timer? _pulseTimer;
  double _pulseT = 0;

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
  // than fetching a separate global set.
  Squad? _mySquad;
  Set<String> _squadMemberIds = {};
  StreamSubscription<Squad?>? _squadSub;
  StreamSubscription<List<SquadPresenceMember>>? _presenceSub;
  bool _showSquadHeatmap = false;
  final _squadHeatmapFillsByTerritoryId = <String, List<Fill>>{};

  @override
  void initState() {
    super.initState();
    unawaited(_locateSelf());
    unawaited(_loadRivalAndDecayStatus());
    _loadSquadInfo();
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
        unawaited(_redrawSquadHeatmap());
        return;
      }
      _presenceSub = getIt<WatchSquadPresence>()(squad.id).listen((members) {
        if (!mounted) return;
        setState(() {
          _squadMemberIds = members.map((m) => m.userId).toSet();
        });
        unawaited(_redrawSquadHeatmap());
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
    // view entirely (see MapStyleLoader) — any Fill/Line handles from
    // before the swap belong to a now-destroyed view, so they can't be
    // passed to removeFills/removeLines on the new controller. The new view
    // starts with none.
    _fillsByTerritoryId.clear();
    _bountyFillsByZoneId.clear();
    _outlineLinesByTerritoryId.clear();
    _atRiskPulseLinesByTerritoryId.clear();
    _squadHeatmapFillsByTerritoryId.clear();
    _pulseTimer?.cancel();
    _pulseTimer = null;
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

  /// Health (0-100) for an owned territory, derived from
  /// `TerritoryAtRisk.lastDefendedAt`/`expiresAt` (the only decay signal
  /// this app's backend currently exposes to the client — `Territory`
  /// itself has no `health` column). A territory absent from the at-risk
  /// list is outside the decay warning window entirely, i.e. full health.
  /// Used to fade owned-fill opacity (item 6) and to gate the pulsing
  /// at-risk border (item 5).
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

    final allFills = _fillsByTerritoryId.values.expand((f) => f).toList();
    if (allFills.isNotEmpty) {
      await controller.removeFills(allFills);
    }
    _fillsByTerritoryId.clear();

    final allOutlineLines = [
      ..._outlineLinesByTerritoryId.values.expand((l) => l),
      ..._atRiskPulseLinesByTerritoryId.values.expand((l) => l),
    ];
    if (allOutlineLines.isNotEmpty) {
      await controller.removeLines(allOutlineLines);
    }
    _outlineLinesByTerritoryId.clear();
    _atRiskPulseLinesByTerritoryId.clear();

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

    for (final territory in _lastTerritories) {
      if (!territory.isMine && !_showRivalTerritory) continue;
      final polygons = TerritoryMapStyle.territoryPolygonsToLatLng(territory);
      final fills = <Fill>[];
      final lines = <Line>[];

      // Single source of truth for ownership colors (item 2) — both this
      // fill/outline logic and `_TerritoryLegend` below now read the same
      // `context.semanticColors` roles instead of two independently
      // hardcoded hex literals.
      final fillColor = territory.isMine
          ? semantic.territoryOwnedFill
          : semantic.territoryRivalFill;
      final outlineColor = territory.isMine
          ? semantic.territoryOwned
          : semantic.territoryRival;

      // Health decay texture (item 6): fade owned-fill opacity down as
      // health drops, so defending territory feels visually urgent on the
      // map itself. Full opacity at health 100, ~40% of the base opacity
      // by health 25 and below. Rival territory has no health signal
      // available to this client, so it stays at a flat base opacity.
      final baseOpacity = territory.isMine ? 0.40 : 0.32;
      final health = territory.isMine
          ? _healthOf(territory.id, atRiskById)
          : 100.0;
      final healthFactor = (0.4 + 0.6 * ((health - 25).clamp(0, 75) / 75))
          .clamp(0.4, 1.0);
      final targetOpacity = territory.isMine
          ? baseOpacity * healthFactor
          : baseOpacity;

      final isAnimatingCapture =
          territory.isMine && newlyCaptured.contains(territory.id);

      for (final rings in polygons) {
        final fill = await controller.addFill(
          FillOptions(
            geometry: rings,
            fillColor: _colorToHex(fillColor),
            fillOpacity: isAnimatingCapture ? 0 : targetOpacity,
            fillOutlineColor: _colorToHex(outlineColor),
          ),
        );
        fills.add(fill);

        if (rings.isEmpty) continue;
        final outerRing = rings.first;

        if (!territory.isMine) {
          // Color-only differentiation fix (item 3): rival territory gets
          // a dashed outline built from broken line segments (see
          // `TerritoryMapStyle.ringToDashSegments`'s doc comment on why —
          // this `maplibre_gl` version has no line-dash paint property),
          // distinct from owned territory's solid `fillOutlineColor`.
          for (final segment in TerritoryMapStyle.ringToDashSegments(
            outerRing,
          )) {
            if (segment.length < 2) continue;
            final line = await controller.addLine(
              LineOptions(
                geometry: segment,
                lineColor: _colorToHex(outlineColor),
                lineWidth: 2,
              ),
            );
            lines.add(line);
          }
        } else if (atRiskById.containsKey(territory.id)) {
          // Pulsing at-risk border (item 5) — a separate solid `Line` on
          // top of the fill, whose width/opacity are ticked by
          // `_tickPulse` via `updateLine` (see `_updatePulseTimer`).
          final line = await controller.addLine(
            LineOptions(
              geometry: outerRing,
              lineColor: _colorToHex(semantic.territoryAtRisk),
              lineWidth: 3,
            ),
          );
          _atRiskPulseLinesByTerritoryId
              .putIfAbsent(territory.id, () => [])
              .add(line);
        }
      }
      _fillsByTerritoryId[territory.id] = fills;
      if (lines.isNotEmpty) _outlineLinesByTerritoryId[territory.id] = lines;

      if (isAnimatingCapture) {
        unawaited(_animateCaptureGrowIn(fills, targetOpacity));
      }
    }

    _updatePulseTimer();
  }

  /// Capture is an event, not a state swap (item 7): a newly-captured
  /// territory's fill ramps from transparent to its target opacity over
  /// `MotionTokens.defaultSpatial` (~500ms) instead of popping straight to
  /// full color. `maplibre_gl`'s annotation API has no built-in
  /// paint-property animation/interpolation — `updateFill` sets a value
  /// immediately — so this drives it with a stepped ramp of `updateFill`
  /// calls instead, which is the option available within that API.
  Future<void> _animateCaptureGrowIn(
    List<Fill> fills,
    double targetOpacity,
  ) async {
    if (fills.isEmpty) return;
    final controllerAtStart = _controller;
    if (controllerAtStart == null) return;
    if (mounted && MediaQuery.disableAnimationsOf(context)) {
      for (final fill in fills) {
        await controllerAtStart.updateFill(
          fill,
          FillOptions(fillOpacity: targetOpacity),
        );
      }
      return;
    }
    const steps = 6;
    final stepMs = (MotionTokens.defaultSpatial.inMilliseconds / steps).round();
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(Duration(milliseconds: stepMs));
      // A style-tier swap tears down and recreates the native map view
      // mid-animation — its Fill handles belong to a destroyed view, so
      // bail rather than call `updateFill` against a stale controller.
      if (_controller != controllerAtStart) return;
      final opacity = targetOpacity * (i / steps);
      for (final fill in fills) {
        await controllerAtStart.updateFill(
          fill,
          FillOptions(fillOpacity: opacity),
        );
      }
    }
  }

  /// Starts/stops the periodic `updateLine` ticker driving the pulsing
  /// at-risk border (item 5). Guarded by `MediaQuery.disableAnimationsOf`
  /// for reduce-motion — a static (non-pulsing, still-present) border still
  /// gets drawn in `_redrawFills` either way, so reduce-motion users don't
  /// lose the at-risk signal, only its animation.
  void _updatePulseTimer() {
    if (_atRiskPulseLinesByTerritoryId.isEmpty) {
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
    if (controller == null || _atRiskPulseLinesByTerritoryId.isEmpty) return;
    _pulseT += 0.12;
    final t = (math.sin(_pulseT * math.pi) + 1) / 2; // 0..1..0 loop
    final width = 2.0 + t * 3.0;
    final opacity = 0.5 + t * 0.5;
    for (final lines in _atRiskPulseLinesByTerritoryId.values) {
      for (final line in lines) {
        await controller.updateLine(
          line,
          LineOptions(lineWidth: width, lineOpacity: opacity),
        );
      }
    }
  }

  /// Squad territory heatmap (item 11) — an aggregated tinted overlay
  /// distinct from the individual owned/rival colors above, covering every
  /// territory owned by the caller or by an online squad member. Drawn as
  /// a second, low-opacity underlay so it doesn't obscure the per-member
  /// coloring it's layered on top of.
  Future<void> _redrawSquadHeatmap() async {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final existing = _squadHeatmapFillsByTerritoryId.values
        .expand((f) => f)
        .toList();
    if (existing.isNotEmpty) {
      await controller.removeFills(existing);
    }
    _squadHeatmapFillsByTerritoryId.clear();

    if (!_showSquadHeatmap || !mounted) return;
    final semantic = context.semanticColors;
    final tint = Color.lerp(semantic.territoryOwned, Colors.white, 0.15)!;

    for (final territory in _lastTerritories) {
      if (!territory.isMine && !_squadMemberIds.contains(territory.ownerId)) {
        continue;
      }
      final polygons = TerritoryMapStyle.territoryPolygonsToLatLng(territory);
      final fills = <Fill>[];
      for (final rings in polygons) {
        final fill = await controller.addFill(
          FillOptions(
            geometry: rings,
            fillColor: _colorToHex(tint),
            fillOpacity: 0.22,
          ),
        );
        fills.add(fill);
      }
      _squadHeatmapFillsByTerritoryId[territory.id] = fills;
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
          // `Rival` (domain/entities/rival.dart) carries no coordinate, and
          // `ActiveRunPage` takes no start-location param, so this opens the
          // normal active-run flow rather than a rival-centered map — a
          // real gap, not a client oversight (see squad_page.dart audit
          // note near `_RivalCard`'s import in this file).
          if (!isWinner) ...[
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ActiveRunPage()),
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
