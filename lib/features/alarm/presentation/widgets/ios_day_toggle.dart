import 'package:flutter/material.dart';

class IosDayToggle extends StatelessWidget {
  const IosDayToggle({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;
    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.surfaceContainer;
    final unselectedFg = isDark ? Colors.white70 : scheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Was 36dp tall — below WCAG 2.5.5's 48dp minimum. Seven of these
        // sit in a row on a narrow phone with no horizontal room to grow,
        // so unlike the pill/stepper fixes above, height grows in place
        // instead of via a separate hit-area wrapper.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: selected ? accentColor : unselectedBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : unselectedFg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
