import 'package:flutter/material.dart';

import '../../../../core/theme/shape_tokens.dart';

/// Loading placeholder for `StatTile` — same size/shape (padding, icon
/// circle, value/label lines) as the real tile, so the layout doesn't jump
/// once the underlying stream produces its first value. Wrapped in
/// [_Pulsing] rather than a static gray block so it doesn't read as a
/// permanently-broken tile.
class SkeletonStatTile extends StatelessWidget {
  const SkeletonStatTile({super.key, this.radius = ShapeTokens.small});

  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pulsing(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: radius,
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 32,
                height: 18,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 48,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic pulsing placeholder block — used for the recent-activity
/// section's loading rows, matching each real row's approximate
/// height/shape.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, required this.height, required this.radius});

  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pulsing(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: radius,
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
    );
  }
}

/// Shared shimmer loop for the skeleton placeholders above — a plain
/// `AnimatedOpacity` toggled on a timer between 0.4 and 1.0, per the audit's
/// "no new package needed" note (no `shimmer`/`skeletonizer` dependency).
class _Pulsing extends StatefulWidget {
  const _Pulsing({required this.child});

  final Widget child;

  @override
  State<_Pulsing> createState() => _PulsingState();
}

class _PulsingState extends State<_Pulsing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
