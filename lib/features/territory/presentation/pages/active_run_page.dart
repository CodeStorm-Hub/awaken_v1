import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/gps_quality.dart';
import '../../domain/entities/run_track_state.dart';
import '../../domain/entities/track_point.dart';
import '../bloc/run_tracking_cubit.dart';
import '../widgets/territory_capture_sheet.dart';
import '../widgets/territory_map_tiles.dart';

/// Active-run tracking. Redesigned per the territory feature review + design
/// research (Strava's "Map + Stats" redesign — the live map and the run
/// stats are shown together on one screen, not switched between). The
/// route trace is now the *real* tracked GPS path (`RunTrackState.points`)
/// rendered on a real `flutter_map`, replacing the fixed stylized
/// `CustomPaint` bezier shape the page previously showed regardless of
/// where the user actually went.
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
  final _mapController = MapController();
  bool _busy = false;
  bool _autoFollow = true;
  int _lastCenteredPointCount = 0;

  String _fmtTime(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _maybeFollow(RunTrackState state) {
    if (!_autoFollow || state.points.isEmpty) return;
    if (state.points.length == _lastCenteredPointCount) return;
    _lastCenteredPointCount = state.points.length;
    final last = state.points.last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(last.latitude, last.longitude), _mapController.camera.zoom);
    });
  }

  Future<void> _capture(RunTrackingCubit cubit) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await cubit.capture();
    if (!mounted) return;

    if (result.pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run saved — will sync territory once back online.')),
      );
      Navigator.of(context).pop();
      return;
    }
    if (result.accepted != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.rejectedReason ?? "Run couldn't be captured.")),
      );
      Navigator.of(context).pop();
      return;
    }

    final areaSqm = result.capturedAreaSqm ?? result.territoryAreaSqm ?? 0;
    final areaLabel = '${(areaSqm / 1000000).toStringAsFixed(3)} km²';
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => TerritoryCaptureSheet(areaLabel: areaLabel),
    );
    if (mounted) Navigator.of(context).pop();
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
            builder: (context, state) {
              if (state.permissionDenied) {
                return _PermissionDeniedView(onClose: () => Navigator.of(context).pop());
              }

              _maybeFollow(state);

              final loopClosed = state.isLoopClosed;
              final distanceKm = state.distanceMeters / 1000;
              final elapsedSec = state.elapsed.inSeconds;
              final paceSecPerKm = distanceKm > 0.01 ? (elapsedSec / distanceKm).round() : 0;
              final loopProgress = (state.distanceMeters / 400).clamp(0, 1).toDouble();

              return Column(
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scheme.onSurface),
                            ),
                          ],
                        ),
                        _GpsQualityChip(quality: state.gpsQuality),
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
                            _RunMap(
                              controller: _mapController,
                              points: state.points,
                              scheme: scheme,
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: _RoundMapButton(
                                icon: _autoFollow ? Icons.gps_fixed : Icons.gps_not_fixed,
                                tooltip: _autoFollow ? 'Following your position' : 'Recenter',
                                onTap: () {
                                  setState(() => _autoFollow = true);
                                  if (state.points.isNotEmpty) {
                                    final last = state.points.last;
                                    _mapController.move(LatLng(last.latitude, last.longitude), 17);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                            radius: const BorderRadius.horizontal(left: Radius.circular(24)),
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
                            value: paceSecPerKm > 0 ? _fmtTime(paceSecPerKm) : '--:--',
                            label: 'Pace /km',
                            radius: const BorderRadius.horizontal(right: Radius.circular(24)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: loopClosed ? 1 : loopProgress),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder: (context, animatedProgress, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    loopClosed ? Icons.check_circle : Icons.route,
                                    size: 22,
                                    color: loopClosed ? scheme.primary : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      loopClosed
                                          ? 'Loop closed — ready to capture!'
                                          : 'Keep going — return near your start point to close the loop.',
                                      style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: animatedProgress,
                                  minHeight: 6,
                                  backgroundColor: scheme.surfaceContainerHighest,
                                  color: loopClosed ? scheme.primary : scheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.96, end: loopClosed ? 1 : 0.96),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(60),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                              onPressed: (loopClosed && !_busy) ? () => _capture(cubit) : null,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                          onPressed: _busy ? null : () => _abandon(cubit),
                          child: const Text('Stop without capturing'),
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
    );
  }
}

class _RunMap extends StatelessWidget {
  const _RunMap({required this.controller, required this.points, required this.scheme});

  final MapController controller;
  final List<TrackPoint> points;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final latLngPoints = [for (final p in points) LatLng(p.latitude, p.longitude)];
    final current = latLngPoints.isNotEmpty ? latLngPoints.last : const LatLng(20, 0);

    return FlutterMap(
      mapController: controller,
      options: MapOptions(initialCenter: current, initialZoom: latLngPoints.isNotEmpty ? 17 : 2),
      children: [
        if (isAnyTileProviderConfigured)
          const ResilientTerritoryTileLayer()
        else
          ColoredBox(color: scheme.surfaceContainerLow),
        if (latLngPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(points: latLngPoints, color: scheme.primary, strokeWidth: 5),
            ],
          ),
        if (latLngPoints.isNotEmpty) ...[
          MarkerLayer(
            markers: [
              Marker(
                point: latLngPoints.first,
                width: 14,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
              ),
              Marker(
                point: current,
                width: 20,
                height: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (isAnyTileProviderConfigured) const ResilientTerritoryAttribution(),
      ],
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({required this.icon, required this.tooltip, required this.onTap});

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
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: scheme.onSurface)),
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
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Icon(Icons.gps_fixed, size: 15, color: scheme.onPrimaryContainer),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
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

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);
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
      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}
