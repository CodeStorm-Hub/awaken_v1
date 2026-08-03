import 'package:flutter/material.dart';

import '../../../../core/theme/semantic_colors.dart';
import '../../domain/entities/gps_quality.dart';

class GpsQualityChip extends StatelessWidget {
  const GpsQualityChip({super.key, required this.quality});

  final GpsQuality quality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    // Audit finding (item 3): previously every quality band used the same
    // `primaryContainer` background and the same `gps_fixed` icon — "weak"
    // and "good" were indistinguishable to anyone relying on shape/icon
    // rather than reading the label text. Now each band gets its own icon
    // and its own `gpsGood`/`gpsWeak` tint.
    final (label, icon, color) = switch (quality) {
      GpsQuality.none => (
        'Finding GPS…',
        Icons.location_searching,
        scheme.onSurfaceVariant,
      ),
      GpsQuality.good => ('GPS good', Icons.gps_fixed, semantic.gpsGood),
      GpsQuality.degraded => ('GPS fair', Icons.gps_not_fixed, semantic.gpsWeak),
      GpsQuality.poor => ('GPS weak', Icons.gps_off, semantic.gpsWeak),
    };
    return Container(
      // A hard `height:` forces the child Row into that exact cross-axis
      // size — at large system text scale the label needs more than 32dp
      // and overflows (`RenderFlex`) instead of the chip growing.
      // `constraints` with only a minimum lets it grow.
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
