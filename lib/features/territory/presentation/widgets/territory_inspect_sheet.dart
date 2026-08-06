import 'package:flutter/material.dart';

import '../../../../core/theme/semantic_colors.dart';

/// Tap-to-inspect bottom sheet content (Conquest Skyline redesign) — shown
/// when a territory fill/extrusion feature is tapped on the map. Pure
/// presentation: every value is already computed by the caller
/// (`TerritoryPage._showTerritoryInspectSheet`), which owns the map-state
/// lookups (squadmate name, at-risk health, centroid) this sheet doesn't
/// need to know about.
class TerritoryInspectSheet extends StatelessWidget {
  const TerritoryInspectSheet({
    super.key,
    required this.ownerLabel,
    required this.ownerColor,
    required this.areaLabel,
    required this.health,
    required this.canStealBack,
    required this.onStealBack,
  });

  final String ownerLabel;
  final Color ownerColor;
  final String areaLabel;

  /// Null when the territory isn't the caller's own (health is only shown
  /// for owned territories).
  final double? health;
  final bool canStealBack;
  final VoidCallback onStealBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return Container(
      decoration: BoxDecoration(
        color: scheme.brightness == Brightness.dark
            ? const Color(0xFF1C1C1E)
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: ownerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ownerLabel,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                areaLabel,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              if (health != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${health!.round()}% defended',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (health! / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: health! < 30
                        ? semantic.territoryAtRisk
                        : semantic.territoryOwned,
                  ),
                ),
              ],
              if (canStealBack) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: semantic.territoryRival,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: onStealBack,
                    icon: const Icon(Icons.directions_run),
                    label: const Text('Steal back'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
