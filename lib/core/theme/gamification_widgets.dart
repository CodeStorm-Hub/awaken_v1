import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../../features/squad/domain/entities/streak_tier.dart';
import 'motion_tokens.dart';
import 'semantic_colors.dart';

/// Wraps an avatar (or any circular child) with a tier-colored ring —
/// `profiles.streak_tier` / `StreakTier` already exists server-side and
/// was, per the 2026-07-29 UI/UX audit, only ever rendered as plain text
/// on a leaderboard row. This makes it a persistent, glanceable badge
/// wherever an avatar appears (Home top bar, Profile, Squad member cards)
/// instead of something a user only sees by opening the leaderboard sheet.
class StreakTierAvatarRing extends StatelessWidget {
  const StreakTierAvatarRing({
    required this.tier,
    required this.child,
    this.size = 44,
    this.ringWidth = 3,
    super.key,
  });

  final StreakTier tier;
  final Widget child;

  /// Outer diameter including the ring — [child] is expected to fill this
  /// minus [ringWidth] * 2 padding.
  final double size;
  final double ringWidth;

  /// Tier → ring color. Bronze/silver are fixed "metal" hues that read
  /// correctly in both themes without needing brightness-specific tuning
  /// (unlike saturated accent colors); gold reuses the semantic bounty-gold
  /// role so "gold streak" and "gold bounty" share one visual language.
  Color? _ringColor(BuildContext context) => switch (tier) {
    StreakTier.none => null,
    StreakTier.bronze => const Color(0xFFB08D57),
    StreakTier.silver => const Color(0xFFA8AEB8),
    StreakTier.gold => context.semanticColors.bountyGold,
  };

  @override
  Widget build(BuildContext context) {
    final ring = _ringColor(context);
    if (ring == null) {
      return SizedBox(width: size, height: size, child: Center(child: child));
    }
    return Semantics(
      label: '${tier.label} streak tier',
      child: AnimatedContainer(
        duration: MotionTokens.fastSpatial,
        curve: MotionTokens.spatialCurve,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [ring, ring.withValues(alpha: 0.35), ring],
          ),
        ),
        padding: EdgeInsets.all(ringWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: ClipOval(child: child),
          ),
        ),
      ),
    );
  }
}

/// Persistent "wake-up tax" debt visualization — `user_stats.
/// current_tax_multiplier` / `WakeUpTaxStore.watch()` already exist and
/// drive the required-reps math on the ring screen, but per the audit
/// there was no persistent place a user could see their current debt
/// building up (only a one-off banner shown mid-ring). This renders as a
/// small horizontal meter: empty at the 1.0x floor, full at
/// [AppConstants.penaltyMultiplierCap], using the warning semantic role
/// so it reads as "penalty," not a neutral stat.
class WakeUpTaxMeter extends StatelessWidget {
  const WakeUpTaxMeter({required this.multiplier, super.key});

  final double multiplier;

  double get _fraction {
    const floor = 1.0;
    final cap = AppConstants.penaltyMultiplierCap;
    return ((multiplier - floor) / (cap - floor)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (multiplier <= 1.0) return const SizedBox.shrink();
    final colors = context.semanticColors;
    return Semantics(
      label:
          'Wake-up tax active: ${multiplier.toStringAsFixed(1)} times normal reps',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.warningContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: colors.warning),
            const SizedBox(width: 6),
            Text(
              '×${multiplier.toStringAsFixed(1)} tax',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.onWarningContainer,
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: 48,
                height: 5,
                child: Stack(
                  children: [
                    Container(color: colors.warning.withValues(alpha: 0.18)),
                    AnimatedFractionallySizedBox(
                      duration: MotionTokens.defaultSpatial,
                      curve: MotionTokens.effectsCurve,
                      widthFactor: _fraction,
                      alignment: Alignment.centerLeft,
                      child: Container(color: colors.warning),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
