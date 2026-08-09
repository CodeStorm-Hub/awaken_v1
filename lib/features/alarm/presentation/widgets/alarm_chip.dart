import 'package:flutter/material.dart';
import '../../../../core/theme/shape_tokens.dart';

/// Small pill-shaped label chip used on [AlarmCard]. Named `AlarmChip`
/// (rather than `Chip`) to avoid clashing with Flutter's own `Chip` widget.
class AlarmChip extends StatelessWidget {
  const AlarmChip({
    super.key,
    required this.bg,
    required this.fg,
    required this.label,
    this.icon,
  });

  final Color bg;
  final Color fg;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: ShapeTokens.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
