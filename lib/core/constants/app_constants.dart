/// Cross-feature constants sourced from awaken_app_refined_plan.md. Kept in
/// one place so tuning a threshold never requires hunting through features.
abstract final class AppConstants {
  // Territory / geospatial (plan §3, §6 Phase 5)
  static const double loopClosureRadiusMeters = 30;
  static const double minRunLengthMeters = 400;
  static const double maxSustainedSpeedMetersPerSecond = 7; // ~human sprint

  // Alarm / wake-up tax (plan §2.3 — bounded, not unbounded exponential)
  static const double penaltyMultiplierStep = 1.5;
  static const double penaltyMultiplierCap = 4.0;

  // Verification pipeline (plan §6 Phase 2 exit criterion)
  static const int targetPoseProcessingFps = 12; // 10-15 fps budget
  static const double calibrationRepCount = 3;

  // Sync engine (plan §6 Phase 3)
  static const Duration syncInitialBackoff = Duration(minutes: 2);
  static const Duration syncMaxBackoff = Duration(minutes: 30);

  // Squad networking (`SquadRepositoryImpl`'s one-shot Supabase reads)
  static const Duration squadNetworkReadTimeout = Duration(seconds: 10);
  static const Duration squadBroadcastThrottle = Duration(seconds: 3);
  static const Duration squadLeaderboardPollInterval = Duration(seconds: 20);

  // Squad streak tiers (plan §6 Phase 6) — mirrored in the
  // `recompute_streak_tier()` Postgres trigger (migration
  // `add_squad_social_phase6`); keep both in sync if these change.
  static const int bronzeStreakTierThreshold = 3;
  static const int silverStreakTierThreshold = 7;
  static const int goldStreakTierThreshold = 14;

  // Legal — hosted via GitHub Pages from docs/ (see docs/index.html's
  // redirect and the "chore: add privacy policy page for GitHub Pages"
  // commit). Confirm Settings → Pages is enabled for this repo before
  // relying on these in a Play Store submission — a 404 here is a Play
  // Console rejection reason, not just a broken in-app link.
  static const String privacyPolicyUrl =
      'https://codestorm-hub.github.io/awaken_v1/privacy-policy.html';
  static const String termsAndConditionsUrl =
      'https://codestorm-hub.github.io/awaken_v1/terms.html';
}
