import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../widgets/territory_capture_sheet.dart';

/// Active-run tracking (Claude Design handoff — `isActiveRun`). Concept-only
/// — no real GPS/geolocator wiring here, same caveat as `TerritoryPage`.
/// Elapsed time/distance/loop-closure are simulated on a 1s timer, mirroring
/// the handoff's own `setInterval` mock.
class ActiveRunPage extends StatefulWidget {
  const ActiveRunPage({super.key});

  @override
  State<ActiveRunPage> createState() => _ActiveRunPageState();
}

class _ActiveRunPageState extends State<ActiveRunPage> {
  static const _loopCloseSec = 8;

  Timer? _timer;
  int _elapsedSec = 0;
  double _distanceM = 0;
  final _random = Random();

  bool get _loopClosed => _elapsedSec >= _loopCloseSec;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSec += 1;
        _distanceM += 2.8 + _random.nextDouble() * 0.6;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtTime(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _capture() async {
    if (!_loopClosed) return;
    _timer?.cancel();
    final gainedM2 = 8000 + _random.nextInt(6000);
    final areaLabel = '${(gainedM2 / 1000000).toStringAsFixed(3)} km²';
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => TerritoryCaptureSheet(areaLabel: areaLabel),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _abandon() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distanceKm = _distanceM / 1000;
    final paceSecPerKm = distanceKm > 0 ? (_elapsedSec / distanceKm).round() : 0;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) => _timer?.cancel(),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scheme.onSurface),
                        ),
                      ],
                    ),
                    Container(
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
                            'GPS good',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
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
                        progress: (_elapsedSec / _loopCloseSec).clamp(0, 1).toDouble(),
                        trackColor: scheme.outlineVariant,
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
                        value: _fmtTime(_elapsedSec),
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
                        _loopClosed ? Icons.check_circle : Icons.route,
                        size: 22,
                        color: _loopClosed ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _loopClosed
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
                        onPressed: _loopClosed ? _capture : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.flag, size: 22),
                            SizedBox(width: 8),
                            Text('Close loop & capture'),
                          ],
                        ),
                      ),
                    ),
                    TextButton(onPressed: _abandon, child: const Text('Stop without capturing')),
                  ],
                ),
              ),
            ],
          ),
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
