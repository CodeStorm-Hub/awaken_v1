import 'package:flutter/material.dart';

class IosStepButton extends StatelessWidget {
  const IosStepButton({
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
    final accentColor = scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : scheme.surfaceContainer;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Was 32x32 — below WCAG 2.5.5's 48x48 minimum; circle stays the
        // same visual size, centered in a larger tap area.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: accentColor),
            ),
          ),
        ),
      ),
    );
  }
}
