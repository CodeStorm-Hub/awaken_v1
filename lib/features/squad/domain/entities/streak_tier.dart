import '../../../../core/constants/app_constants.dart';

/// Squad streak tier (plan §6 Phase 6) — computed server-side by the
/// `recompute_streak_tier()` Postgres trigger from `sessions`, never
/// client-reported (a client-reported tier would be spoofable and other
/// squad members need to trust it).
enum StreakTier {
  none(0),
  bronze(1),
  silver(2),
  gold(3);

  const StreakTier(this.value);

  final int value;

  /// Mirrors the SQL trigger's thresholds (`AppConstants` cross-references
  /// the same numbers) — used for display only; the source of truth is
  /// always the server-computed `profiles.streak_tier` value this maps.
  factory StreakTier.fromValue(int value) => switch (value) {
    >= 3 => StreakTier.gold,
    2 => StreakTier.silver,
    1 => StreakTier.bronze,
    _ => StreakTier.none,
  };

  String get label => switch (this) {
    StreakTier.none => 'No streak',
    StreakTier.bronze => 'Bronze',
    StreakTier.silver => 'Silver',
    StreakTier.gold => 'Gold',
  };
}

/// Pure function mirroring the SQL trigger's day-count → tier mapping, kept
/// here for the two places that need it client-side (tests, and any UI
/// wanting to preview a tier from a streak count without a round-trip).
StreakTier streakTierForDays(int streakDays) => switch (streakDays) {
  >= AppConstants.goldStreakTierThreshold => StreakTier.gold,
  >= AppConstants.silverStreakTierThreshold => StreakTier.silver,
  >= AppConstants.bronzeStreakTierThreshold => StreakTier.bronze,
  _ => StreakTier.none,
};
