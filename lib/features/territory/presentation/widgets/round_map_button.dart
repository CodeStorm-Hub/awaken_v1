import 'package:flutter/material.dart';

/// Small circular icon button used for map overlay controls (recenter,
/// zoom in/out) on `ActiveRunPage`.
class RoundMapButton extends StatelessWidget {
  const RoundMapButton({
    super.key,
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
