import '../entities/leaderboard_entry.dart';
import '../entities/squad.dart';
import '../entities/squad_presence_member.dart';

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
  /// null server-side).
  Future<List<LeaderboardEntry>> fetchNearbyLeaderboard({
    required double radiusM,
    required bool weekly,
  });

  /// One-shot global top-N leaderboard.
  Future<List<LeaderboardEntry>> fetchGlobalLeaderboard({required bool weekly});

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
