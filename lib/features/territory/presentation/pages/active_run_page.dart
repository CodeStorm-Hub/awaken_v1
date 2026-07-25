import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
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

  late final _styleLoader = MapStyleLoader(onChange: () => setState(() {}));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheme = Theme.of(context).colorScheme;
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
      await controller.animateCamera(CameraUpdate.newLatLngZoom(current, 17));
    }
  }

  Future<void> _recenter() async {
    final controller = _controller;
    setState(() => _autoFollow = true);
    if (controller == null || _currentMarker == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(_currentMarker!.options.geometry!, 17),
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

  Future<void> _abandon(RunTrackingCubit cubit) async {
    await cubit.abandon();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<RunTrackingCubit>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _abandon(cubit);
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              // Built exactly once — see the class doc comment on why this
                              // must never sit inside a BlocBuilder scoped to RunTrackState.
                              MapLibreMap(
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
                              if (_styleLoader.status ==
                                  MapStyleLoadStatus.retrying)
                                const MapStyleRetryingBanner(),
                              if (_styleLoader.status ==
                                  MapStyleLoadStatus.failed)
                                MapStyleFailureOverlay(
                                  onRetry: _styleLoader.retry,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    BlocBuilder<RunTrackingCubit, RunTrackState>(
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
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.surfaceContainerHigh,
                                      fg: scheme.onSurface,
                                      value: _fmtTime(elapsedSec),
                                      label: 'Time',
                                      radius: const BorderRadius.horizontal(
                                        left: Radius.circular(24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.primaryContainer,
                                      fg: scheme.onPrimaryContainer,
                                      value: distanceKm.toStringAsFixed(2),
                                      label: 'Distance',
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.surfaceContainerHigh,
                                      fg: scheme.onSurface,
                                      value: paceSecPerKm > 0
                                          ? _fmtTime(paceSecPerKm)
                                          : '--:--',
                                      label: 'Pace /km',
                                      radius: const BorderRadius.horizontal(
                                        right: Radius.circular(24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                                      borderRadius: BorderRadius.circular(18),
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
                                                    : 'Keep going — return near your start point to close the loop.',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: animatedProgress,
                                            minHeight: 6,
                                            backgroundColor:
                                                scheme.surfaceContainerHighest,
                                            color: loopClosed
                                                ? scheme.primary
                                                : scheme.tertiary,
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
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0.96,
                                      end: loopClosed ? 1 : 0.96,
                                    ),
                                    duration: const Duration(milliseconds: 350),
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
                                          minimumSize: const Size.fromHeight(
                                            60,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
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
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.flag, size: 22),
                                                  SizedBox(width: 8),
                                                  Text('Close loop & capture'),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _abandon(cubit),
                                    child: const Text('Stop without capturing'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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

class _GpsQualityChip extends StatelessWidget {
  const _GpsQualityChip({required this.quality});

  final GpsQuality quality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (quality) {
      GpsQuality.none => 'Finding GPS…',
      GpsQuality.good => 'GPS good',
      GpsQuality.degraded => 'GPS fair',
      GpsQuality.poor => 'GPS weak',
    };
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_fixed, size: 15, color: scheme.onPrimaryContainer),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
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
