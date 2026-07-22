/// Neutral GPS-fix quality banding for the "GPS quality" chip (plan §5 point
/// 6 — never surface the isMocked/velocity gate as an accusation).
enum GpsQuality {
  /// No fix yet, or the last fix is stale.
  none,
  good,
  degraded,
  poor;

  static GpsQuality fromAccuracyMeters(double accuracy) {
    if (accuracy <= 15) return GpsQuality.good;
    if (accuracy <= 40) return GpsQuality.degraded;
    return GpsQuality.poor;
  }
}
