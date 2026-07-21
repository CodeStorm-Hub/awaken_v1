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
  static const Duration penaltyGraceWindow = Duration(hours: 2);

  // Verification pipeline (plan §6 Phase 2 exit criterion)
  static const int targetPoseProcessingFps = 12; // 10-15 fps budget
  static const double calibrationRepCount = 3;

  // Sync engine (plan §6 Phase 3)
  static const Duration syncInitialBackoff = Duration(minutes: 2);
  static const Duration syncMaxBackoff = Duration(minutes: 30);
}
