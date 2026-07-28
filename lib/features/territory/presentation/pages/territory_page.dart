import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
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

  LatLng _center = const LatLng(20, 0);
  bool _hasFix = false;
  bool _showRivalTerritory = true;

  late final _styleLoader = MapStyleLoader(onChange: () => setState(() {}));

  final _bountyFillsByZoneId = <String, List<Fill>>{};
  Rival? _currentRival;
  List<TerritoryAtRisk> _atRisk = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_locateSelf());
    unawaited(_loadRivalAndDecayStatus());
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
    _bboxRefreshDebounceTimer?.cancel();
    _styleLoader.dispose();
    super.dispose();
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
    // view entirely (see MapStyleLoader) — any Fill handles from before the
    // swap belong to a now-destroyed view, so they can't be passed to
    // removeFills on the new controller. The new view starts with none.
    _fillsByTerritoryId.clear();
    _bountyFillsByZoneId.clear();
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
    if (_hasFix) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_center, _focusZoom),
      );
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

    for (final zone in zones) {
      final ring = _circlePolygon(zone.centerLat, zone.centerLng, zone.radiusM);
      final fill = await controller.addFill(
        FillOptions(
          geometry: [ring],
          fillColor: _colorToHex(const Color(0xFFFFD700)),
          fillOpacity: 0.25,
          fillOutlineColor: _colorToHex(const Color(0xFFFFAB00)),
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
  }

  Future<void> _redrawFills() async {
    final controller = _controller;
    if (controller == null) return;

    final allFills = _fillsByTerritoryId.values.expand((f) => f).toList();
    if (allFills.isNotEmpty) {
      await controller.removeFills(allFills);
    }
    _fillsByTerritoryId.clear();

    for (final territory in _lastTerritories) {
      if (!territory.isMine && !_showRivalTerritory) continue;
      final polygons = TerritoryMapStyle.territoryPolygonsToLatLng(territory);
      final fills = <Fill>[];
      final fillColor = territory.isMine
          ? const Color(0xFF1E66FF)
          : const Color(0xFFFF2A6D);
      final outlineColor = territory.isMine
          ? const Color(0xFF00E5FF)
          : const Color(0xFFFF5252);

      for (final rings in polygons) {
        final fill = await controller.addFill(
          FillOptions(
            geometry: rings,
            fillColor: _colorToHex(fillColor),
            fillOpacity: 0.40,
            fillOutlineColor: _colorToHex(outlineColor),
          ),
        );
        fills.add(fill);
      }
      _fillsByTerritoryId[territory.id] = fills;
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
            Positioned(
              top: topPadding + 64,
              left: 14,
              right: 14,
              child: const MapStyleRetryingBanner(),
            ),
          if (_styleLoader.status == MapStyleLoadStatus.failed)
            MapStyleFailureOverlay(onRetry: _styleLoader.retry),

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
                    _TerritoryLegend(
                      scheme: scheme,
                      showRivalTerritory: _showRivalTerritory,
                    ),
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
                                color: const Color(0xFFFF2A6D),
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
                          SwitchListTile(
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
                              setSheetState(() => _showRivalTerritory = value);
                              setState(() => _showRivalTerritory = value);
                              unawaited(_redrawFills());
                            },
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
  const _TerritoryLegend({
    required this.scheme,
    required this.showRivalTerritory,
  });

  final ColorScheme scheme;
  final bool showRivalTerritory;

  @override
  Widget build(BuildContext context) {
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: const Color(0xFF00E5FF)),
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
            _LegendDot(color: const Color(0xFFFF2A6D)),
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

    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFFF9500).withValues(alpha: 0.6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFFF9500),
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
                const Text(
                  'DEFEND TERRITORY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFFFF9500),
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
    final accentColor = isWinner ? scheme.primary : const Color(0xFFFF2A6D);
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
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
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
