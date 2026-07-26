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
          color: scheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
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
              color: scheme.primary.withValues(alpha: 0.2),
              borderColor: scheme.primary,
              animatePop: true,
              child: Icon(
                Icons.landscape,
                size: 48,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'VICTORY! TERRITORY CLAIMED',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '+$areaLabel added to your empire',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Land is yours until a rival captures it',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
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
                  color: const Color(0xFF2E2300),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 15,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BOUNTY ZONE — ${bountyMultiplier!.toStringAsFixed(0)}x credit applied',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Color(0xFFFFD700),
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
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'CLAIM VICTORY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
