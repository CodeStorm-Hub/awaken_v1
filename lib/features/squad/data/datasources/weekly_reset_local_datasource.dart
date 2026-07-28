import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists "last seen ISO week" + "last known global weekly rank" so the
/// Squad page can detect a weekly-leaderboard rollover and show a one-time
/// recap sheet (2026-07-29 UI/UX audit item 11) — same
/// SharedPreferences-flag pattern as `OnboardingLocalDataSource`.
@lazySingleton
class WeeklyResetLocalDataSource {
  static const _weekKey = 'squad_last_seen_iso_week';
  static const _rankKey = 'squad_last_known_weekly_rank';

  Future<String?> getLastSeenWeek() async =>
      (await SharedPreferences.getInstance()).getString(_weekKey);

  Future<int?> getLastKnownRank() async =>
      (await SharedPreferences.getInstance()).getInt(_rankKey);

  Future<void> save({required String isoWeek, required int? rank}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weekKey, isoWeek);
    if (rank == null) {
      await prefs.remove(_rankKey);
    } else {
      await prefs.setInt(_rankKey, rank);
    }
  }
}
