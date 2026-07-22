import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/gps_quality.dart';
import '../../domain/entities/run_track_state.dart';
import '../bloc/run_tracking_cubit.dart';
import '../widgets/territory_capture_sheet.dart';

/// Active-run tracking (Claude Design handoff — `isActiveRun`). Real GPS
/// tracking (plan §6 Phase 5): `RunTrackingCubit` drives elapsed/distance/
/// loop-closure/GPS-quality from `RunTrackingRepository` (geolocator +
/// kalman_dr EKF smoothing), not the timer/`Random()` mock this page used to
/// run. The route-shape painter stays stylized rather than a real map trace
/// — a real `flutter_map` polygon layer is Phase 5c, a separate effort from
/// wiring up the tracking pipeline itself.
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
  bool _busy = false;

  String _fmtTime(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
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

              final loopClosed = state.isLoopClosed;
              final distanceKm = state.distanceMeters / 1000;
              final elapsedSec = state.elapsed.inSeconds;
              final paceSecPerKm = distanceKm > 0.01 ? (elapsedSec / distanceKm).round() : 0;

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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 190,
                        color: scheme.surfaceContainerLow,
                        child: CustomPaint(
                          painter: _RunPathPainter(
                            progress: (state.distanceMeters / 400).clamp(0, 1).toDouble(),
                            trackColor: scheme.outline,
                            pathColor: scheme.primary,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
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
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      children: [
                        SizedBox(
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

class _RunPathPainter extends CustomPainter {
  const _RunPathPainter({required this.progress, required this.trackColor, required this.pathColor});

  final double progress;
  final Color trackColor;
  final Color pathColor;

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.09, h * 0.82)
      ..cubicTo(w * 0.24, h * 0.24, w * 0.53, h * 0.24, w * 0.65, h * 0.55)
      ..cubicTo(w * 0.76, h * 0.87, w * 0.94, h * 0.87, w * 0.88, h * 0.34);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, trackPaint);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = totalLength * progress;
    final progressPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final extractLength = remaining.clamp(0, metric.length).toDouble();
      canvas.drawPath(metric.extractPath(0, extractLength), progressPaint);
      remaining -= metric.length;
    }

    final start = path.computeMetrics().first.getTangentForOffset(0)?.position;
    if (start != null) {
      canvas.drawCircle(start, 7, Paint()..color = pathColor);
    }
  }

  @override
  bool shouldRepaint(covariant _RunPathPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.trackColor != trackColor || oldDelegate.pathColor != pathColor;
}
