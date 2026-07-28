import '../entities/leaderboard_entry.dart';
import '../entities/squad.dart';
import '../entities/squad_presence_member.dart';
import '../entities/territory_capture_feed_item.dart';

abstract interface class SquadRepository {
  /// The caller's current squad, or `null` if not in one. Re-emits after
  /// [createSquad]/[joinSquad]/[leaveSquad] — this is a manually-driven
  /// stream (fetch-once + re-emit-on-mutation), not a live subscription;
  /// squad membership only ever changes from this same client's own
  /// actions.
  Stream<Squad?> watchMySquad();

  Future<Squad> createSquad(String name);

  Future<Squad> joinSquad(String inviteCode);

  Future<void> leaveSquad();

  /// Polled (plan §6: "leaderboards (polled, geography-computed areas)"),
  /// not a Realtime subscription — active only while listened.
  Stream<List<LeaderboardEntry>> watchLeaderboard(String squadId);

  /// One-shot (not polled, unlike [watchLeaderboard]) — players within
  /// [radiusM] of the caller's own last submitted run location. Empty if
  /// the caller has never submitted a run (`profiles.last_run_location` is
  /// null server-side). [timeWindow] is `'all_time'`/`'weekly'`/`'daily'`
  /// (matches the RPC's `p_time_window` check constraint). [rowLimit] is
  /// the RPC's `p_row_limit` (1-500) — there's no server-side offset/cursor,
  /// so "load more" is implemented by refetching with a larger [rowLimit],
  /// not a true paged cursor.
  Future<List<LeaderboardEntry>> fetchNearbyLeaderboard({
    required double radiusM,
    required String timeWindow,
    int rowLimit = 50,
  });

  /// One-shot global top-N leaderboard. See [fetchNearbyLeaderboard] for
  /// [timeWindow]/[rowLimit] semantics.
  Future<List<LeaderboardEntry>> fetchGlobalLeaderboard({
    required String timeWindow,
    int rowLimit = 50,
  });

  /// Caller's own rank in [fetchGlobalLeaderboard]'s ordering, fetched as an
  /// independent targeted query (`my_global_rank` RPC) rather than scanning
  /// a page-limited list client-side. Null if the caller has captured no
  /// area yet (not on the board).
  Future<int?> fetchMyGlobalRank({required String timeWindow});

  /// Caller's own rank in [fetchNearbyLeaderboard]'s ordering. Null if the
  /// caller has no `last_run_location` yet.
  Future<int?> fetchMyNearbyRank({
    required double radiusM,
    required String timeWindow,
  });

  /// Recent territory captures across all users (`recent_territory_captures`
  /// RPC) for the "conquest ticker" activity feed — most recent first.
  Future<List<TerritoryCaptureFeedItem>> fetchRecentTerritoryCaptures({
    int rowLimit = 10,
  });

  /// Realtime Presence sync/join/leave for the squad's channel — online
  /// members and their current activity label.
  Stream<List<SquadPresenceMember>> watchPresence(String squadId);

  /// Publishes the caller's own presence state (activity label) on their
  /// squad's Presence channel. No-ops if the user has no squad — callers
  /// (e.g. `RunTrackingCubit`/`VerificationCubit`) never need to check
  /// membership themselves, and never need to know the squad id.
  Future<void> trackPresence({required String activity});

  /// Throttled Broadcast telemetry (H6: ≤1 message per ~3s per user) — a
  /// no-op outside the throttle window or when the user has no squad.
  void broadcastTelemetry({required String label});

  /// UGC report mechanism (Google Play/Apple Guideline 1.2 — squads are
  /// invite-code/private, so the lighter "specified set of users" tier
  /// applies: a report path is sufficient, no public block/moderation
  /// queue). Reports are reviewed by the operator directly, never surfaced
  /// back to any client.
  Future<void> reportMember({
    required String reportedUserId,
    required String reason,
  });

  /// Closes any open Realtime channels and clears cached squad state —
  /// called only from account sign-out/switch/delete, immediately before
  /// `AppDatabase.clearAllLocalData()`, so the outgoing identity's squad
  /// membership/channel subscriptions can't leak into the next session.
  Future<void> resetForAccountTransition();
}
