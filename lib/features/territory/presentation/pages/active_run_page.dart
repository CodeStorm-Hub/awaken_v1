import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../domain/entities/geo_bounds.dart';
import '../../domain/entities/run_track_state.dart';
import '../../domain/entities/territory.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/usecases/refresh_territories.dart';
import '../../domain/usecases/watch_territories.dart';
import '../bloc/run_tracking_cubit.dart';
import '../widgets/gps_quality_chip.dart';
import '../widgets/map_style_loader.dart';
import '../widgets/map_style_overlays.dart';
import '../widgets/osm_attribution.dart';
import '../widgets/permission_denied_view.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/round_map_button.dart';
import '../widgets/start_failed_view.dart';
import '../widgets/territory_capture_sheet.dart';
import '../widgets/territory_map_style.dart';
import '../widgets/zoom_controls.dart';

/// Active-run tracking. Redesigned per the territory feature review + design
/// research (Strava's "Map + Stats" redesign — the live map and run stats
/// share one screen). Renders the *real* tracked GPS path on a real
/// `maplibre_gl` map (replaced `flutter_map`, which can't consume
/// OpenFreeMap's vector-only tiles without a much larger integration).
///
/// Performance note (this is the reason the page used to feel laggy): the
/// map widget is built exactly **once**, in this widget's own `build()`,
/// and never wrapped in a `BlocBuilder` — a live run emits a new
/// `RunTrackState` every second purely from the elapsed-time timer tick
/// (independent of GPS updates), and if the map widget sat inside that
/// rebuild scope it would reconstruct/re-diff on every tick regardless of
/// whether anything about the route actually changed. Route/marker/camera
/// updates instead go through the `MapLibreMapController` imperatively (a
/// handful of lightweight method-channel calls), driven by a `BlocListener`
/// that no-ops whenever the point count hasn't changed — so a plain
/// 1-second elapsed tick touches only the (cheap) stat-tile text, never the
/// map.
class ActiveRunPage extends StatelessWidget {
  const ActiveRunPage({super.key, this.focusLocation});

  /// Where the map should start centered, before any GPS fix arrives —
  /// used by `TerritoryPage`'s "Steal back" CTA to open this page already
  /// looking at the rival's territory instead of the default
  /// `LatLng(20, 0)` zoomed-out world view. Null (the default) keeps the
  /// old behavior.
  final LatLng? focusLocation;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RunTrackingCubit>(
      create: (_) => getIt<RunTrackingCubit>()..begin(),
      child: _ActiveRunView(focusLocation: focusLocation),
    );
  }
}

class _ActiveRunView extends StatefulWidget {
  const _ActiveRunView({this.focusLocation});

  final LatLng? focusLocation;

  @override
  State<_ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<_ActiveRunView>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  static const _activeUserLocationSourceId = 'awaken-active-user-location-source';
  static const _activeUserLocationPulseLayerId = 'awaken-active-user-location-pulse';
  static const _activeUserLocationOuterLayerId = 'awaken-active-user-location-outer';
  static const _activeUserLocationInnerLayerId = 'awaken-active-user-location-inner';
  bool _activeUserLocationLayerReady = false;
  LatLng? _lastPosition;

  Line? _routeLine;
  Circle? _startMarker;
  bool _avatarIconRegistered = false;
  int _syncedPointCount = 0;
  bool _autoFollow = true;
  bool _busy = false;
  ColorScheme? _scheme;

  AnimationController? _locationAnimController;
  LatLng? _previousLocation;

  // Minimal territory context (territory map 3D redesign §5.4) — a plain
  // fill overlay of whatever owned/rival territory rows are already cached
  // nearby, so the game-world framing doesn't disappear the moment a run
  // starts. Deliberately not the full `TerritoryPage` treatment (no
  // extrusion/glow/animated outlines, no legend, no toggle) — this page's
  // map is built exactly once and never inside a rebuild scope (see class
  // doc comment), and a full redraw pipeline here would be a much bigger
  // change than "some context" calls for.
  static const _territoryContextSourceId = 'active-run-territory-context-source';
  static const _territoryContextFillLayerId = 'active-run-territory-context-fill-layer';
  bool _territoryContextLayerReady = false;
  StreamSubscription<List<Territory>>? _territoriesSub;
  LatLng? _lastRefreshedNear;

  late final _styleLoader = MapStyleLoader(
    onChange: () => setState(() {}),
    isDark: Theme.of(context).brightness == Brightness.dark,
  );

  @override
  void initState() {
    super.initState();
    _locationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
        if (_previousLocation != null && _lastPosition != null) {
          final t = _locationAnimController!.value;
          final lat = lerpDouble(_previousLocation!.latitude, _lastPosition!.latitude, t)!;
          final lng = lerpDouble(_previousLocation!.longitude, _lastPosition!.longitude, t)!;
          unawaited(_updateMarkerLocation(LatLng(lat, lng)));
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheme = Theme.of(context).colorScheme;
    // Same correction as `TerritoryPage` — see `_styleLoader` field's doc
    // comment on `MapStyleLoader._isDark`.
    _styleLoader.updateBrightness(
      Theme.of(context).brightness == Brightness.dark,
    );
  }

  @override
  void dispose() {
    _locationAnimController?.dispose();
    unawaited(_territoriesSub?.cancel());
    _styleLoader.dispose();
    super.dispose();
  }

  String _fmtTime(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    // A fallback-tier style swap tears down and recreates the native map
    // view entirely (see MapStyleLoader) — any Line/Circle handles and the
    // synced-point count from before the swap belong to a now-destroyed
    // view, so the whole route must be re-synced onto the fresh one.
    _routeLine = null;
    _startMarker = null;
    _avatarIconRegistered = false;
    _activeUserLocationLayerReady = false;
    _syncedPointCount = 0;
    _styleLoaded = false;
    _territoryContextLayerReady = false;
    _controller = controller;
    _styleLoader.start();
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    _styleLoader.onStyleLoaded();
    // Captured before any `await` below (the new focus-location
    // `animateCamera` call among them) — `context.read` after an async gap
    // trips `use_build_context_synchronously` even though this widget's
    // `context` doesn't actually change across the gap.
    final cubit = context.read<RunTrackingCubit>();
    final controller = _controller;
    if (controller != null) {
      // Same Pokémon-GO-inspired basemap recolor as `TerritoryPage` — see
      // `TerritoryBasemapRecolor`'s doc comment for the mechanism (applied
      // per style load via `setLayerProperties`, not a pre-patched style
      // JSON). Kept in sync here too since this page renders its own
      // `MapLibreMap` on the same OpenFreeMap style tiers.
      final isDark = mounted && Theme.of(context).brightness == Brightness.dark;
      unawaited(TerritoryBasemapRecolor.apply(controller, isDark: isDark));
      // Real 3D city buildings (territory map 3D redesign §5.4 — extends
      // §5.1's `TerritoryPage` treatment to the live-run map) — same
      // fallback-tier gate as `TerritoryPage._onStyleLoaded`.
      if (!_styleLoader.isDegradedFallback) {
        unawaited(
          TerritoryBasemapRecolor.applyCityBuildings(
            controller,
            isDark: isDark,
          ),
        );
      }
      if (!_avatarIconRegistered) {
        try {
          final bytes = await TerritoryMapStyle.generateAvatarPuckIconBytes(
            color: const Color(0xFF00E5FF),
          );
          await controller.addImage(
            TerritoryMapStyle.avatarPuckIconNamePrefix,
            bytes,
          );
          _avatarIconRegistered = true;
        } catch (_) {
          // Best-effort — see `TerritoryPage`'s identical registration.
        }
      }
      // Re-affirm the focus location once the style is actually ready,
      // mirroring `TerritoryPage._onStyleLoaded`'s explicit follow-up after
      // `initialCameraPosition` — belt-and-braces in case a real GPS fix
      // (which would otherwise recenter via `_syncMapAnnotations`'s
      // `_autoFollow` branch) hasn't arrived yet. Only while no route point
      // has been drawn yet, so this never fights a live run already in
      // progress after a style-tier fallback swap.
      if (widget.focusLocation != null && _lastPosition == null) {
        await controller.animateCamera(
          _cameraUpdateFor(widget.focusLocation!),
        );
      }
      // A fallback-tier style swap tears down and recreates the native map
      // view (see MapStyleLoader), so this can run more than once per page
      // lifetime — cancel any previous subscription first, same pattern as
      // `TerritoryPage._onStyleLoaded`.
      await _territoriesSub?.cancel();
      _territoriesSub = getIt<WatchTerritories>()().listen(
        _redrawTerritoryContext,
      );
      if (widget.focusLocation != null) {
        unawaited(_refreshNearbyTerritories(widget.focusLocation!));
      }
    }
    await _handleStateChange(cubit.state);
  }

  /// Minimal territory context (§5.4) — a plain translucent fill of
  /// whatever owned/rival territory rows `WatchTerritories` already has
  /// cached, no legend/toggle/animation. Lazily adds the source/layer on
  /// first call, then just refreshes the source data on every later call.
  Future<void> _redrawTerritoryContext(List<Territory> territories) async {
    final controller = _controller;
    if (controller == null || !mounted || !_styleLoaded) return;
    final semantic = context.semanticColors;
    final collection = {
      'type': 'FeatureCollection',
      'features': [
        for (final territory in territories)
          TerritoryMapStyle.territoryToGeoJsonFeature(territory, {
            'fillColor': _colorToHex(
              territory.isMine
                  ? semantic.territoryOwnedFill
                  : semantic.territoryRivalFill,
            ),
          }),
      ],
    };
    if (!_territoryContextLayerReady) {
      await controller.addGeoJsonSource(_territoryContextSourceId, collection);
      // Below the route line/markers (all annotations, not style layers) so
      // territory context never obscures the tracked path.
      await controller.addFillLayer(
        _territoryContextSourceId,
        _territoryContextFillLayerId,
        const FillLayerProperties(
          fillColor: ['get', 'fillColor'],
          fillOpacity: 0.22,
        ),
      );
      _territoryContextLayerReady = true;
    } else {
      await controller.setGeoJsonSource(_territoryContextSourceId, collection);
    }
  }

  /// Debounced by distance rather than time — a run can cover kilometers, so
  /// this re-refreshes whenever the tracked point has moved far enough that
  /// the last fetched bounding box (padded ~800m) may no longer cover it,
  /// not on a fixed timer.
  static const _territoryContextRadiusM = 800.0;

  Future<void> _refreshNearbyTerritories(LatLng center) async {
    if (_lastRefreshedNear != null) {
      final movedM = _haversineMeters(_lastRefreshedNear!, center);
      if (movedM < _territoryContextRadiusM / 2) return;
    }
    _lastRefreshedNear = center;
    const earthRadiusM = 6371000.0;
    final latRad = center.latitude * (math.pi / 180);
    final dLat =
        (_territoryContextRadiusM / earthRadiusM) * (180 / math.pi);
    final dLng = (_territoryContextRadiusM / (earthRadiusM * math.cos(latRad))) *
        (180 / math.pi);
    try {
      await getIt<RefreshTerritories>()(
        GeoBounds(
          minLat: center.latitude - dLat,
          minLng: center.longitude - dLng,
          maxLat: center.latitude + dLat,
          maxLng: center.longitude + dLng,
        ),
      );
    } catch (_) {
      // Best-effort — the run's own tracking/capture flow doesn't depend on
      // this context layer loading successfully.
    }
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h));
  }

  /// Guarded imperative sync — a plain elapsed-time tick leaves `points`
  /// unchanged (same length), so this returns immediately without touching
  /// the map at all. Only a genuinely new GPS fix does real work.
  Future<void> _handleStateChange(RunTrackState state) async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || state.permissionDenied) return;
    if (state.points.length == _syncedPointCount) return;
    _syncedPointCount = state.points.length;
    await _syncMapAnnotations(controller, state.points);
  }

  Future<void> _syncMapAnnotations(
    MapLibreMapController controller,
    List<TrackPoint> points,
  ) async {
    if (points.isEmpty) return;
    final scheme = _scheme;
    if (scheme == null) return;
    final latLngPoints = [
      for (final p in points) TerritoryMapStyle.trackPointToLatLng(p),
    ];
    final current = latLngPoints.last;
    _previousLocation = _lastPosition ?? current;
    _lastPosition = current;
    unawaited(_locationAnimController?.forward(from: 0.0));

    _startMarker ??= await controller.addCircle(
      CircleOptions(
        geometry: latLngPoints.first,
        circleRadius: 6,
        circleColor: _colorToHex(scheme.tertiary),
        circleStrokeColor: _colorToHex(scheme.surface),
        circleStrokeWidth: 2,
      ),
    );

    if (latLngPoints.length >= 2) {
      if (_routeLine == null) {
        _routeLine = await controller.addLine(
          LineOptions(
            geometry: latLngPoints,
            lineColor: _colorToHex(scheme.primary),
            lineWidth: 4,
          ),
        );
      } else {
        await controller.updateLine(
          _routeLine!,
          LineOptions(geometry: latLngPoints),
        );
      }
    }

    if (_autoFollow) {
      await controller.animateCamera(_cameraUpdateFor(current));
    }
    unawaited(_refreshNearbyTerritories(current));
  }

  Future<void> _recenter() async {
    setState(() {
      _autoFollow = true;
    });
    unawaited(_recenterCamera());
  }

  Future<void> _recenterCamera() async {
    final controller = _controller;
    if (controller == null || _lastPosition == null) return;
    await controller.animateCamera(
      _cameraUpdateFor(_lastPosition!),
    );
  }

  Future<void> _updateMarkerLocation(LatLng pos) async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    final locationGeojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [pos.longitude, pos.latitude],
          },
        },
      ],
    };

    if (!_activeUserLocationLayerReady) {
      try {
        await controller.addSource(
          _activeUserLocationSourceId,
          GeojsonSourceProperties(data: locationGeojson),
        );
        await controller.addCircleLayer(
          _activeUserLocationSourceId,
          _activeUserLocationPulseLayerId,
          const CircleLayerProperties(
            circleRadius: 18,
            circleColor: '#00E5FF',
            circleOpacity: 0.18,
            circlePitchAlignment: 'viewport',
          ),
        );
        await controller.addCircleLayer(
          _activeUserLocationSourceId,
          _activeUserLocationOuterLayerId,
          const CircleLayerProperties(
            circleRadius: 9,
            circleColor: '#FFFFFF',
            circlePitchAlignment: 'viewport',
          ),
        );
        await controller.addCircleLayer(
          _activeUserLocationSourceId,
          _activeUserLocationInnerLayerId,
          const CircleLayerProperties(
            circleRadius: 6.5,
            circleColor: '#00E5FF',
            circlePitchAlignment: 'viewport',
          ),
        );
        _activeUserLocationLayerReady = true;
      } catch (_) {}
    } else {
      try {
        await controller.setGeoJsonSource(
          _activeUserLocationSourceId,
          locationGeojson,
        );
      } catch (_) {}
    }
  }

  /// Territory map 3D redesign §5.4: the live-run map defaults to a tilted
  /// camera too, same as `TerritoryPage`, so the run takes place "inside"
  /// the 3D world rather than reverting to flat top-down. Unlike
  /// `TerritoryPage`, this page has no 3D/2D toggle — a live run's
  /// follow-camera recentering happens every GPS fix, so a fixed tilt (not a
  /// per-call preserved one) is enough here.
  static const _tilt = 45.0;

  /// `CameraUpdate.newLatLngZoom` always resets `tilt` to 0 — see
  /// `TerritoryPage._cameraUpdateForFocus`'s identical note.
  CameraUpdate _cameraUpdateFor(LatLng target) => CameraUpdate.newCameraPosition(
    CameraPosition(target: target, zoom: _focusZoom, tilt: _tilt),
  );

  /// The follow/recenter zoom, clamped to the active style tier's data
  /// ceiling (see `MapStyleLoader.dataMaxZoom`) — otherwise the bundled
  /// fallback tier overzooms into a single illegible blown-up tile
  /// fragment instead of a legible degraded map. Found live on an emulator:
  /// after a forced style-tier fallback, the map was interactive and the
  /// position marker tracked correctly, but the screen showed one uniform
  /// color with no visible coastline/borders anywhere, even after panning
  /// — the signature of viewing a single low-zoom tile blown up far past
  /// its native resolution.
  double get _focusZoom => math.min(17, _styleLoader.dataMaxZoom ?? 17);

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

  Future<void> _capture(RunTrackingCubit cubit) async {
    if (_busy) return;
    setState(() => _busy = true);
    // Every early return below previously skipped resetting `_busy` on an
    // exception from `cubit.capture()` or the modal sheet — the capture
    // button would stay permanently disabled for the rest of this page's
    // lifetime. `finally` guarantees it resets regardless of how this
    // method exits (including the `Navigator.pop()` paths, which no-op
    // harmlessly against a widget that's about to be disposed anyway).
    try {
      final result = await cubit.capture();
      if (!mounted) return;

      if (result.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Run saved — will sync territory once back online.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      if (result.accepted != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.rejectedReason ?? "Run couldn't be captured."),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      final baseAreaSqm =
          result.capturedAreaSqm ?? result.territoryAreaSqm ?? 0;
      final areaSqm = baseAreaSqm + (result.bonusAreaSqm ?? 0);
      final areaLabel = '${(areaSqm / 1000000).toStringAsFixed(3)} km²';
      unawaited(HapticFeedback.mediumImpact());
      // Capture moment (territory map 3D redesign §5.6) — a camera fly-to
      // over the newly-claimed block, so the "VICTORY!" sheet below is
      // paired with an actual visual payoff on the map instead of being a
      // detached modal. Closer zoom + steeper tilt than the run's normal
      // follow camera; best-effort (a run's capture must never fail because
      // a camera animation did) and only when a position is actually known.
      final captureLocation = _lastPosition;
      if (captureLocation != null) {
        try {
          // `easeCamera` + `easeOut` (not `animateCamera`, which has no
          // interpolation param) — a snappier arrival for this one-off
          // "victory" fly-to versus the run's normal follow-camera easing.
          await _controller?.easeCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: captureLocation, zoom: 18.5, tilt: 60),
            ),
            interpolation: CameraAnimationInterpolation.easeOut,
          );
        } catch (_) {}
      }
      // Refresh territories immediately after capture instead of waiting for
      // the debounced distance check — the run's own capture just changed
      // the very block the fly-to above is centered on.
      if (captureLocation != null) {
        _lastRefreshedNear = null;
        unawaited(_refreshNearbyTerritories(captureLocation));
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => TerritoryCaptureSheet(
          areaLabel: areaLabel,
          bountyMultiplier: result.bountyMultiplier,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Confirms before discarding tracked progress — a back gesture or "Stop
  /// without capturing" previously abandoned the run (distance, time, the
  /// whole tracked path) with zero confirmation, the only unconfirmed
  /// destructive action in the app (compare: deleting an *alarm* confirms).
  Future<bool> _confirmAbandon(
    BuildContext context,
    RunTrackingCubit cubit,
  ) async {
    final state = cubit.state;
    if (!state.isTracking) return true;
    final distanceKm = (state.distanceMeters / 1000).toStringAsFixed(2);
    final elapsedSec = state.elapsed.inSeconds;
    final m = (elapsedSec ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSec % 60).toString().padLeft(2, '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this run?'),
        content: Text(
          "You'll lose $distanceKm km and $m:$s tracked so far — this run "
          "won't be saved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep running'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _abandon(BuildContext context, RunTrackingCubit cubit) async {
    if (!await _confirmAbandon(context, cubit)) return;
    await cubit.abandon();
    // Checked on the passed-in `context`, not `State.mounted` — this
    // `context` can belong to a nested builder (the "Stop without
    // capturing" call site) that unmounts independently of the page itself.
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<RunTrackingCubit>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _abandon(context, cubit);
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: BlocBuilder<RunTrackingCubit, RunTrackState>(
            buildWhen: (previous, current) =>
                previous.permissionDenied != current.permissionDenied ||
                previous.startFailed != current.startFailed,
            builder: (context, gateState) {
              if (gateState.permissionDenied) {
                return PermissionDeniedView(
                  onClose: () => Navigator.of(context).pop(),
                );
              }
              if (gateState.startFailed) {
                return StartFailedView(
                  onRetry: () => context.read<RunTrackingCubit>().begin(),
                  onClose: () => Navigator.of(context).pop(),
                );
              }

              return BlocListener<RunTrackingCubit, RunTrackState>(
                listener: (context, state) => _handleStateChange(state),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PulsingDot(color: scheme.error),
                                const SizedBox(width: 8),
                                Text(
                                  'Tracking run',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: scheme.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          BlocBuilder<RunTrackingCubit, RunTrackState>(
                            buildWhen: (previous, current) =>
                                previous.gpsQuality != current.gpsQuality,
                            builder: (context, state) =>
                                GpsQualityChip(quality: state.gpsQuality),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23),
                            child: Stack(
                              children: [
                                // A static label, not one driven by
                                // `RunTrackState` — the map is deliberately
                                // built exactly once and never inside a
                                // `BlocBuilder` (see this file's class doc
                                // comment on why); the live distance/time/
                                // loop-status figures are already announced
                                // via the `StatTile` texts below this map,
                                // which already track state live.
                                Semantics(
                                  label: 'Live run route map',
                                  child: RepaintBoundary(
                                    child: MapLibreMap(
                                      key: _styleLoader.styleKey,
                                      styleString: _styleLoader.styleString,
                                      initialCameraPosition:
                                          widget.focusLocation != null
                                          ? CameraPosition(
                                              target: widget.focusLocation!,
                                              zoom: _focusZoom,
                                              tilt: _tilt,
                                            )
                                          : const CameraPosition(
                                              target: LatLng(20, 0),
                                              zoom: 2,
                                              tilt: _tilt,
                                            ),
                                      onMapCreated: _onMapCreated,
                                      onStyleLoadedCallback: _onStyleLoaded,
                                      onMapLongClick: (_, _) => unawaited(HapticFeedback.mediumImpact()),
                                      compassEnabled: false,
                                      myLocationEnabled: false,
                                      logoEnabled: false,
                                      attributionButtonPosition:
                                          AttributionButtonPosition.bottomLeft,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 4,
                                  right: 8,
                                  child: OsmAttribution(),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: RoundMapButton(
                                    icon: _autoFollow
                                        ? Icons.gps_fixed
                                        : Icons.gps_not_fixed,
                                    tooltip: _autoFollow
                                        ? 'Following your position'
                                        : 'Recenter',
                                    onTap: _recenter,
                                  ),
                                ),
                                Positioned(
                                  top: 64,
                                  right: 10,
                                  child: ZoomControls(
                                    scheme: scheme,
                                    onZoomIn: _zoomIn,
                                    onZoomOut: _zoomOut,
                                  ),
                                ),
                                if (_styleLoader.status ==
                                    MapStyleLoadStatus.retrying)
                                  const MapStyleRetryingBanner(),
                                if (_styleLoader.status ==
                                    MapStyleLoadStatus.failed)
                                  MapStyleFailureOverlay(
                                    onRetry: _styleLoader.retry,
                                  ),
                                // Persistent, unlike the retrying banner
                                // above — stays up for as long as the
                                // loader is on the bundled offline fallback
                                // tier (see `MapStyleLoader.isDegradedFallback`).
                                if (_styleLoader.isDegradedFallback)
                                  const MapDegradedModeChip(top: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // At large system text scale this block's intrinsic
                    // height can exceed the space the sibling `Expanded` map
                    // leaves it, which previously overflowed (`RenderFlex`)
                    // rather than yielding — `Flexible` + `SingleChildScrollView`
                    // lets it shrink and scroll internally instead. The map
                    // widget itself is untouched — it stays built exactly
                    // once inside its own `Expanded`, per this page's
                    // no-rebuild-on-tick performance note.
                    Flexible(
                      child: SingleChildScrollView(
                        child: BlocBuilder<RunTrackingCubit, RunTrackState>(
                          builder: (context, state) {
                            final loopClosed = state.isLoopClosed;
                            final distanceKm = state.distanceMeters / 1000;
                            final elapsedSec = state.elapsed.inSeconds;
                            final paceSecPerKm = distanceKm > 0.01
                                ? (elapsedSec / distanceKm).round()
                                : 0;
                            final loopProgress = (state.distanceMeters / 400)
                                .clamp(0, 1)
                                .toDouble();

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    0,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: StatTile(
                                            bg: Colors.transparent,
                                            fg: scheme.onSurface,
                                            value: _fmtTime(elapsedSec),
                                            label: 'Time',
                                            icon: Icons.timer_outlined,
                                            radius: BorderRadius.circular(14),
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: StatTile(
                                            bg: scheme.primaryContainer.withValues(alpha: 0.35),
                                            fg: scheme.primary,
                                            value: distanceKm.toStringAsFixed(2),
                                            label: 'Distance (km)',
                                            icon: Icons.directions_run,
                                            radius: BorderRadius.circular(14),
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: StatTile(
                                            bg: Colors.transparent,
                                            fg: scheme.onSurface,
                                            value: paceSecPerKm > 0
                                                ? _fmtTime(paceSecPerKm)
                                                : '--:--',
                                            label: 'Pace /km',
                                            icon: Icons.speed_outlined,
                                            radius: BorderRadius.circular(14),
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    0,
                                  ),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0,
                                      end: loopClosed ? 1 : loopProgress,
                                    ),
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOut,
                                    builder: (context, animatedProgress, _) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: loopClosed
                                                ? scheme.primary.withValues(alpha: 0.5)
                                                : scheme.outlineVariant.withValues(alpha: 0.25),
                                            width: loopClosed ? 1.5 : 1,
                                          ),
                                          boxShadow: [
                                            if (loopClosed)
                                              BoxShadow(
                                                color: scheme.primary.withValues(alpha: 0.15),
                                                blurRadius: 10,
                                              ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  loopClosed
                                                      ? Icons.check_circle_rounded
                                                      : Icons.route_rounded,
                                                  size: 18,
                                                  color: loopClosed
                                                      ? scheme.primary
                                                      : scheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    loopClosed
                                                        ? 'Loop closed — ready to capture!'
                                                        : loopProgress >= 1
                                                        ? 'Head back toward start point.'
                                                        : 'Return near start to close loop.',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                      color: scheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${state.distanceMeters.clamp(0, 400).toStringAsFixed(0)}/400 m',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: loopClosed ? scheme.primary : scheme.onSurfaceVariant,
                                                    fontFeatures: const [FontFeature.tabularFigures()],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            LinearProgressIndicator(
                                              value: animatedProgress,
                                              minHeight: 5,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              backgroundColor: scheme
                                                  .surfaceContainerHighest,
                                              color: loopClosed
                                                  ? scheme.primary
                                                  : scheme.tertiary,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Semantics(
                                          hint: loopClosed
                                              ? null
                                              : loopProgress < 1
                                              ? '${(400 - state.distanceMeters).clamp(0, 400).toStringAsFixed(0)} '
                                                    'more meters of minimum distance needed before this can '
                                                    'be enabled.'
                                              : '${state.distanceToStartMeters.toStringAsFixed(0)} '
                                                    'meters from your starting point — get within 30 meters '
                                                    'to close the loop and enable this.',
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(
                                              begin: 0.96,
                                              end: loopClosed ? 1 : 0.96,
                                            ),
                                            duration: const Duration(
                                              milliseconds: 350,
                                            ),
                                            curve: Curves.easeOutBack,
                                            builder: (context, scale, child) =>
                                                Transform.scale(
                                                  scale: scale,
                                                  child: child,
                                                ),
                                            child: FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: loopClosed ? scheme.primary : scheme.surfaceContainerHigh,
                                                foregroundColor: loopClosed ? scheme.onPrimary : scheme.onSurfaceVariant,
                                                elevation: loopClosed ? 3 : 0,
                                                shadowColor: scheme.primary.withValues(alpha: 0.3),
                                                minimumSize: const Size.fromHeight(48),
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                              ),
                                              onPressed: (loopClosed && !_busy)
                                                  ? () => _capture(cubit)
                                                  : null,
                                              child: _busy
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          loopClosed ? Icons.flag_rounded : Icons.lock_outlined,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        const FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Text(
                                                            'Close loop & capture',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          foregroundColor: scheme.error,
                                          side: BorderSide(
                                            color: scheme.error.withValues(alpha: 0.3),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _abandon(context, cubit),
                                        icon: const Icon(Icons.stop_rounded, size: 18),
                                        label: const Text(
                                          'Stop',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _colorToHex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2)}';
}
