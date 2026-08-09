import 'package:flutter/material.dart';

import 'round_map_button.dart';
import '../../../../core/theme/shape_tokens.dart';

/// Manual zoom in/out — pinch gestures already reach the full zoom range
/// (`MapLibreMap`'s default `minMaxZoomPreference` is unbounded), so this is
/// purely a tap-target/accessibility affordance for anyone who can't
/// perform a pinch gesture.
class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
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
        borderRadius: ShapeTokens.pill,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundMapButton(icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
          RoundMapButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onTap: onZoomOut,
          ),
        ],
      ),
    );
  }
}
