import 'package:flutter/material.dart';

class IosModePill extends StatelessWidget {
  const IosModePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Was ~26dp tall (padding-driven, no minimum) — below WCAG 2.5.5's
      // 48dp minimum. `SizedBox`+`Center` extends the tap area without
      // changing the pill's visual size, same pattern as `ExpressiveSwitch`.
      child: SizedBox(
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? accentColor : unselectedBg,
              borderRadius: BorderRadius.circular(999),
            ),
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
