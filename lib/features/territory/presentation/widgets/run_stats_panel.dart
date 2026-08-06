import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/run_track_state.dart';

String _fmtTime(int totalSec) {
  final m = (totalSec ~/ 60).toString().padLeft(2, '0');
  final s = (totalSec % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Stat tiles + loop-progress card + capture/stop buttons shown below the
/// live-run map. Pure presentation — reads only the already-computed
/// `RunTrackState` and a couple of primitives; every action (`onCapture`/
/// `onAbandon`) is a plain callback into `ActiveRunPage`'s state, which
/// still owns the `MapLibreMapController`/`BlocBuilder` this widget is
/// nested inside (unchanged: this stays a `BlocBuilder`-scoped subtree in
/// the caller, not a rebuild-scope change).
class RunStatsPanel extends StatelessWidget {
  const RunStatsPanel({
    super.key,
    required this.state,
    required this.scheme,
    required this.busy,
    required this.onCapture,
    required this.onAbandon,
  });

  final RunTrackState state;
  final ColorScheme scheme;
  final bool busy;
  final VoidCallback onCapture;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    final loopClosed = state.isLoopClosed;
    final distanceKm = state.distanceMeters / 1000;
    final elapsedSec = state.elapsed.inSeconds;
    final paceSecPerKm = distanceKm > 0.01
        ? (elapsedSec / distanceKm).round()
        : 0;
    final loopProgress = (state.distanceMeters / 400).clamp(0, 1).toDouble();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: StatTile(
                    bg: Colors.transparent,
                    fg: scheme.onSurface,
                    value: paceSecPerKm > 0 ? _fmtTime(paceSecPerKm) : '--:--',
                    label: 'Pace /km',
                    icon: Icons.speed_outlined,
                    radius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: loopClosed ? 1 : loopProgress),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: loopClosed
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: animatedProgress,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: loopClosed ? scheme.primary : scheme.tertiary,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                    tween: Tween(begin: 0.96, end: loopClosed ? 1 : 0.96),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: loopClosed
                            ? scheme.primary
                            : scheme.surfaceContainerHigh,
                        foregroundColor: loopClosed
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                        elevation: loopClosed ? 3 : 0,
                        shadowColor: scheme.primary.withValues(alpha: 0.3),
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: (loopClosed && !busy) ? onCapture : null,
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  loopClosed
                                      ? Icons.flag_rounded
                                      : Icons.lock_outlined,
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
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: busy ? null : onAbandon,
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text(
                  'Stop',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
