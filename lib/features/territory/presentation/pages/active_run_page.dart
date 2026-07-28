import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../domain/entities/gps_quality.dart';
import '../../domain/entities/run_track_state.dart';
import '../../domain/entities/track_point.dart';
import '../bloc/run_tracking_cubit.dart';
import '../widgets/map_style_loader.dart';
import '../widgets/map_style_overlays.dart';
import '../widgets/osm_attribution.dart';
import '../widgets/territory_capture_sheet.dart';
import '../widgets/territory_map_style.dart';

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
  const ActiveRunPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RunTrackingCubit>(
      create: (_) => getIt<RunTrackingCubit>()..begin(),
      child: const _ActiveRunView(),
    );
  }
}

class _ActiveRunView extends StatefulWidget {
  const _ActiveRunView();

  @override
  State<_ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<_ActiveRunView> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  Line? _routeLine;
  Circle? _startMarker;
  Circle? _currentMarker;
  int _syncedPointCount = 0;
  bool _autoFollow = true;
  bool _busy = false;
  ColorScheme? _scheme;

  late final _styleLoader = MapStyleLoader(
    onChange: () => setState(() {}),
    isDark: Theme.of(context).brightness == Brightness.dark,
  );

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
    _currentMarker = null;
    _syncedPointCount = 0;
    _styleLoaded = false;
    _controller = controller;
    _styleLoader.start();
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    _styleLoader.onStyleLoaded();
    final cubit = context.read<RunTrackingCubit>();
    await _handleStateChange(cubit.state);
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

    _startMarker ??= await controller.addCircle(
      CircleOptions(
        geometry: latLngPoints.first,
        circleRadius: 6,
        circleColor: _colorToHex(scheme.tertiary),
        circleStrokeColor: _colorToHex(scheme.surface),
        circleStrokeWidth: 2,
      ),
    );

    if (_currentMarker == null) {
      _currentMarker = await controller.addCircle(
        CircleOptions(
          geometry: current,
          circleRadius: 8,
          circleColor: _colorToHex(scheme.primary),
          circleStrokeColor: _colorToHex(scheme.surface),
          circleStrokeWidth: 3,
        ),
      );
    } else {
      await controller.updateCircle(
        _currentMarker!,
        CircleOptions(geometry: current),
      );
    }

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
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(current, _focusZoom),
      );
    }
  }

  Future<void> _recenter() async {
    final controller = _controller;
    setState(() => _autoFollow = true);
    if (controller == null || _currentMarker == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(_currentMarker!.options.geometry!, _focusZoom),
    );
  }

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
    await _controller?.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    await _controller?.animateCamera(CameraUpdate.zoomOut());
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
                return _PermissionDeniedView(
                  onClose: () => Navigator.of(context).pop(),
                );
              }
              if (gateState.startFailed) {
                return _StartFailedView(
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _PulsingDot(color: scheme.error),
                              const SizedBox(width: 8),
                              Text(
                                'Tracking run',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          BlocBuilder<RunTrackingCubit, RunTrackState>(
                            buildWhen: (previous, current) =>
                                previous.gpsQuality != current.gpsQuality,
                            builder: (context, state) =>
                                _GpsQualityChip(quality: state.gpsQuality),
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
                              color: scheme.primary.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
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
                                  child: MapLibreMap(
                                    key: _styleLoader.styleKey,
                                    styleString: _styleLoader.styleString,
                                    initialCameraPosition: const CameraPosition(
                                      target: LatLng(20, 0),
                                      zoom: 2,
                                    ),
                                    onMapCreated: _onMapCreated,
                                    onStyleLoadedCallback: _onStyleLoaded,
                                    myLocationEnabled: false,
                                    logoEnabled: false,
                                    attributionButtonPosition:
                                        AttributionButtonPosition.bottomLeft,
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
                                  child: _RoundMapButton(
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
                                  child: _ZoomControls(
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
                                    12,
                                    16,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: StatTile(
                                          bg: scheme.surfaceContainerHigh,
                                          fg: scheme.onSurface,
                                          value: _fmtTime(elapsedSec),
                                          label: 'Time',
                                          icon: Icons.timer_outlined,
                                          radius: const BorderRadius.horizontal(
                                            left: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: StatTile(
                                          bg: scheme.surfaceContainerHigh,
                                          fg: scheme.primary,
                                          value: distanceKm.toStringAsFixed(2),
                                          label: 'Distance (km)',
                                          icon: Icons.place_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: StatTile(
                                          bg: scheme.surfaceContainerHigh,
                                          fg: scheme.onSurface,
                                          value: paceSecPerKm > 0
                                              ? _fmtTime(paceSecPerKm)
                                              : '--:--',
                                          label: 'Pace /km',
                                          icon: Icons.speed,
                                          radius: const BorderRadius.horizontal(
                                            right: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
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
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  loopClosed
                                                      ? Icons.check_circle
                                                      : Icons.route,
                                                  size: 22,
                                                  color: loopClosed
                                                      ? scheme.primary
                                                      : scheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    loopClosed
                                                        ? 'Loop closed — ready to capture!'
                                                        // Distinct copy once the
                                                        // minimum-distance bar
                                                        // below is already full —
                                                        // otherwise a straight
                                                        // out-and-back run pins
                                                        // the bar at 100% (it
                                                        // only tracks distance,
                                                        // not proximity to
                                                        // start) with no
                                                        // explanation of why the
                                                        // loop still isn't
                                                        // closing.
                                                        : loopProgress >= 1
                                                        ? 'Minimum distance covered — head back toward your start point.'
                                                        : 'Keep going — return near your start point to close the loop.',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: scheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            LinearProgressIndicator(
                                              value: animatedProgress,
                                              minHeight: 6,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              backgroundColor: scheme
                                                  .surfaceContainerHighest,
                                              color: loopClosed
                                                  ? scheme.primary
                                                  : scheme.tertiary,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              loopClosed
                                                  ? 'Min. distance covered'
                                                  : 'Min. distance: '
                                                        '${state.distanceMeters.clamp(0, 400).toStringAsFixed(0)}'
                                                        '/400 m',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: scheme.onSurfaceVariant,
                                              ),
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
                                    16,
                                    16,
                                    20,
                                  ),
                                  child: Column(
                                    children: [
                                      // Audit finding (item 10): the button
                                      // gave no accessible explanation of
                                      // *why* it was disabled pre-closure —
                                      // a screen-reader user heard only
                                      // "Close loop & capture, disabled."
                                      // The hint below sources the same
                                      // remaining-distance figures the
                                      // sighted progress bar above already
                                      // shows.
                                      Semantics(
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
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: FilledButton(
                                              style: FilledButton.styleFrom(
                                                minimumSize:
                                                    const Size.fromHeight(60),
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
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                          ),
                                                    )
                                                  : Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: const [
                                                        Icon(
                                                          Icons.flag,
                                                          size: 22,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Close loop & capture',
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _abandon(context, cubit),
                                        child: const Text(
                                          'Stop without capturing',
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

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
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
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          // Was 38x38 — below WCAG 2.5.5's 44x44 minimum, found in
          // accessibility review. Icon stays visually the same size.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 18, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Manual zoom in/out — pinch gestures already reach the full zoom range
/// (`MapLibreMap`'s default `minMaxZoomPreference` is unbounded), so this is
/// purely a tap-target/accessibility affordance for anyone who can't
/// perform a pinch gesture.
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
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundMapButton(icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
          _RoundMapButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onTap: onZoomOut,
          ),
        ],
      ),
    );
  }
}

class _GpsQualityChip extends StatelessWidget {
  const _GpsQualityChip({required this.quality});

  final GpsQuality quality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    // Audit finding (item 3): previously every quality band used the same
    // `primaryContainer` background and the same `gps_fixed` icon — "weak"
    // and "good" were indistinguishable to anyone relying on shape/icon
    // rather than reading the label text. Now each band gets its own icon
    // and its own `gpsGood`/`gpsWeak` tint.
    final (label, icon, color) = switch (quality) {
      GpsQuality.none => (
        'Finding GPS…',
        Icons.location_searching,
        scheme.onSurfaceVariant,
      ),
      GpsQuality.good => ('GPS good', Icons.gps_fixed, semantic.gpsGood),
      GpsQuality.degraded => ('GPS fair', Icons.gps_not_fixed, semantic.gpsWeak),
      GpsQuality.poor => ('GPS weak', Icons.gps_off, semantic.gpsWeak),
    };
    return Container(
      // A hard `height:` forces the child Row into that exact cross-axis
      // size — at large system text scale the label needs more than 32dp
      // and overflows (`RenderFlex`) instead of the chip growing.
      // `constraints` with only a minimum lets it grow.
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Location access is needed to track a run.',
              style: TextStyle(color: scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

class _StartFailedView extends StatelessWidget {
  const _StartFailedView({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              "Couldn't start tracking this run. Please try again.",
              style: TextStyle(color: scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onClose, child: const Text('Close')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _startedAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Reduce motion" — same crash/fix pattern as `_RingingBellState` in
    // `alarm_ring_page.dart` and `_StatusBannerState` in
    // `verification_page.dart`: `MediaQuery.disableAnimationsOf` can't be
    // called from `initState`, and the `_startedAnimating` latch keeps a
    // later dependency change from restarting an already-running loop.
    if (!_startedAnimating && !MediaQuery.disableAnimationsOf(context)) {
      _startedAnimating = true;
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
