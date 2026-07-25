import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';

/// Territory-captured celebration (Claude Design handoff —
/// `isTerritoryCelebrate`). `areaLabel` comes from the real `submit_run()`
/// RPC result via `ActiveRunPage._capture` (plan §6 Phase 5).
class TerritoryCaptureSheet extends StatelessWidget {
  const TerritoryCaptureSheet({
    required this.areaLabel,
    this.bountyMultiplier,
    super.key,
  });

  final String areaLabel;

  /// Set only when the capture point fell inside an active bounty zone
  /// (refined territory plan item 1) — e.g. `2.0` for a 2x zone. Null/1.0
  /// shows no bonus badge at all.
  final double? bountyMultiplier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            ExpressiveFlower(
              size: 110,
              color: scheme.primaryContainer,
              animatePop: true,
              child: Icon(
                Icons.landscape,
                size: 48,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Territory captured!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '+$areaLabel added to your map',
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield,
                    size: 15,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Land is yours until a rival captures it',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (bountyMultiplier != null && bountyMultiplier! > 1.0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 15,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Bounty zone — ${bountyMultiplier!.toStringAsFixed(0)}x credit applied',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nice!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
