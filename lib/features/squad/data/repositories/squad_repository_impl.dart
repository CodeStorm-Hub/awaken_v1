import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../territory/domain/usecases/get_current_position.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_presence_member.dart';
import '../../domain/entities/streak_tier.dart';
import '../../domain/entities/territory_capture_feed_item.dart';
import '../../domain/repositories/squad_repository.dart';
import '../datasources/squad_remote_datasource.dart';

/// Online-only, like `TerritoryRepositoryImpl` bypassing `LocalWriter` for
/// its pull-cache — but squad state doesn't even get a local cache, since
/// Presence/Broadcast have no offline meaning at all. `watchMySquad()` is a
/// manually-driven stream (fetch once, re-emit after mutations) rather than
/// a live subscription, since squad membership only ever changes via this
/// same client's own actions.
@LazySingleton(as: SquadRepository)
class SquadRepositoryImpl implements SquadRepository {
  SquadRepositoryImpl(this._remote, this._supabase);

  final SquadRemoteDataSource _remote;
  final SupabaseClient _supabase;

  final _mySquadController = StreamController<Squad?>.broadcast();
  final _refreshFailureController = StreamController<Object>.broadcast();
  Squad? _cachedSquad;
  bool _fetchedOnce = false;
  bool _hasEmittedOnce = false;

  @override
  Stream<Object> get refreshFailures => _refreshFailureController.stream;

  DateTime? _lastBroadcastAt;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Squad _squadFromJson(Map<String, dynamic> json) => Squad(
    id: json['id'] as String,
    name: json['name'] as String,
    inviteCode: json['invite_code'] as String,
    ownerId: json['owner_id'] as String,
  );

  /// A real bug found via live device testing: `_mySquadController` is a
  /// broadcast controller, which never replays past events to a listener
  /// that subscribes *after* they were added. `HomePage`'s `WatchMyRank`
  /// stat tile and `SquadCubit` both call this method independently, and
  /// whichever subscribes first (in practice `HomePage`, since it builds
  /// before the `Squad` tab's `BlocProvider` in the shell's `IndexedStack`)
  /// silently consumed the one-shot fetch's result — the *other* listener
  /// then waited forever with nothing to receive, since `_fetchedOnce`
  /// guarantees the underlying fetch only ever runs once. Every new
  /// listener now replays the last known value immediately (once one
  /// exists) before continuing onto live updates, so subscription order
  /// no longer matters.
  @override
  Stream<Squad?> watchMySquad() async* {
    if (!_fetchedOnce) {
      _fetchedOnce = true;
      unawaited(_refreshMySquad());
    }
    if (_hasEmittedOnce) yield _cachedSquad;
    yield* _mySquadController.stream;
  }

  /// Never lets an exception or a hung request leave `watchMySquad()`
  /// silent forever — a real bug found via live device testing (the Squad
  /// tab got stuck on its loading spinner indefinitely because a failed
  /// fetch here never called `_emitSquad`, so `SquadCubit` never left
  /// `SquadStatus.loading`). Fails open to "no squad" only on the very
  /// first fetch (nothing cached yet — the create/join flow is always
  /// reachable from that empty state, so failing open there costs
  /// nothing). A *later* refresh failing (e.g. a dropped connection) no
  /// longer does this — it used to unconditionally fail open too, which
  /// meant a genuine backend/network blip made an already-known squad
  /// membership vanish and look exactly like "you're not in a squad",
  /// misleadingly pushing the user toward create/join instead of just
  /// retrying. Keeping the last-known-good `_cachedSquad` in that case is
  /// strictly better UX even though this refresh has no direct way to
  /// signal the failure back to the UI (no error banner) — surfacing that
  /// is left to a future targeted fix if this proves confusing in
  /// practice.
  Future<void> _refreshMySquad() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        _emitSquad(null);
        return;
      }
      final profile = await _supabase
          .from('profiles')
          .select('squad_id')
          .eq('id', userId)
          .maybeSingle()
          .timeout(AppConstants.squadNetworkReadTimeout);
      final squadId = profile?['squad_id'] as String?;
      if (squadId == null) {
        _emitSquad(null);
        return;
      }
      final row = await _supabase
          .from('squads')
          .select()
          .eq('id', squadId)
          .maybeSingle()
          .timeout(AppConstants.squadNetworkReadTimeout);
      _emitSquad(row == null ? null : _squadFromJson(row));
    } catch (e, st) {
      // Reported so a persistently-failing fetch is visible in prod, not
      // silently invisible forever — see doc comment above for why this
      // still fails open only on the very first fetch.
      unawaited(Sentry.captureException(e, stackTrace: st));
      if (!_hasEmittedOnce) {
        _emitSquad(null);
      } else {
        // Not the first fetch — keep serving `_cachedSquad` as-is, but let
        // the UI know this refresh didn't actually succeed (see
        // `refreshFailures`'s doc comment) instead of staying silent.
        _refreshFailureController.add(e);
      }
    }
  }

  void _emitSquad(Squad? squad) {
    _cachedSquad = squad;
    _hasEmittedOnce = true;
    _mySquadController.add(squad);
  }

  @override
  Future<Squad> createSquad(String name) async {
    final json = await _remote.createSquad(name);
    final squad = _squadFromJson(json);
    _emitSquad(squad);
    return squad;
  }

  @override
  Future<Squad> joinSquad(String inviteCode) async {
    final json = await _remote.joinSquad(inviteCode);
    final squad = _squadFromJson(json);
    _emitSquad(squad);
    return squad;
  }

  @override
  Future<void> leaveSquad() async {
    await _remote.leaveSquad();
    _emitSquad(null);
  }

  /// Standard "competition ranking" (1, 2, 2, 4 — a tie doesn't consume the
  /// next rank number, but the entry after a tied group skips ahead as if
  /// it hadn't been) rather than plain `index + 1`. Rows arrive already
  /// sorted desc by `area_sqm` from the RPC, so equal-area neighbors share a
  /// rank; the UI (`_LeaderboardRow`) renders a shared rank as "T-N" by
  /// comparing a row's rank against its neighbors'.
  ///
  /// [rankOffset] is the number of rows that precede this page (i.e. the
  /// `p_offset` the page was fetched with) — needed now that
  /// [fetchGlobalLeaderboard]/[fetchNearbyLeaderboard] page via a true
  /// server-side cursor instead of always refetching from row 0, so `rank`
  /// must be `rankOffset + i + 1`, not a page-local `i + 1`. A tie that
  /// straddles a page boundary (last row of one page == first row of the
  /// next) isn't detected across the two separate calls — an accepted, rare
  /// edge case given `area_sqm` is a continuous float.
  List<LeaderboardEntry> _mapLeaderboardRows(
    List<Map<String, dynamic>> rows, {
    String defaultName = 'Player',
    int rankOffset = 0,
  }) {
    final userId = _currentUserId;
    final entries = <LeaderboardEntry>[];
    int? previousRank;
    double? previousArea;
    for (var i = 0; i < rows.length; i++) {
      final area = (rows[i]['area_sqm'] as num?)?.toDouble() ?? 0;
      final rank = (previousArea != null && area == previousArea)
          ? previousRank!
          : rankOffset + i + 1;
      previousRank = rank;
      previousArea = area;
      entries.add(
        LeaderboardEntry(
          rank: rank,
          userId: rows[i]['user_id'] as String,
          displayName: (rows[i]['display_name'] as String?) ?? defaultName,
          streakTier: StreakTier.fromValue(
            (rows[i]['streak_tier'] as num?)?.toInt() ?? 0,
          ),
          areaSqm: area,
          isYou: rows[i]['user_id'] == userId,
          avatarUrl: rows[i]['avatar_url'] as String?,
        ),
      );
    }
    return entries;
  }

  @override
  Stream<List<LeaderboardEntry>> watchLeaderboard(String squadId) async* {
    while (true) {
      // A single failed poll must not kill the whole stream (an unhandled
      // error here would terminate the `async*` generator entirely,
      // silently ending the leaderboard for the rest of the session) —
      // skip this round and retry on the next tick instead.
      try {
        final rows = await _remote
            .fetchLeaderboard(squadId)
            .timeout(AppConstants.squadNetworkReadTimeout);
        yield _mapLeaderboardRows(rows, defaultName: 'Squad member');
      } catch (e, st) {
        // Reported so a persistently-failing poll is visible in prod;
        // still retries next tick regardless (see doc comment above).
        unawaited(Sentry.captureException(e, stackTrace: st));
      }
      await Future<void>.delayed(AppConstants.squadLeaderboardPollInterval);
    }
  }

  @override
  Future<List<LeaderboardEntry>> fetchNearbyLeaderboard({
    required double radiusM,
    required String timeWindow,
    int rowLimit = 50,
    int offset = 0,
  }) async {
    final rows = await _remote.fetchNearbyLeaderboard(
      radiusM: radiusM,
      timeWindow: timeWindow,
      rowLimit: rowLimit,
      offset: offset,
    );
    return _mapLeaderboardRows(rows, rankOffset: offset);
  }

  @override
  Future<List<LeaderboardEntry>> fetchGlobalLeaderboard({
    required String timeWindow,
    int rowLimit = 50,
    int offset = 0,
  }) async {
    final rows = await _remote.fetchGlobalLeaderboard(
      timeWindow: timeWindow,
      rowLimit: rowLimit,
      offset: offset,
    );
    return _mapLeaderboardRows(rows, rankOffset: offset);
  }

  @override
  Future<int?> fetchMyGlobalRank({required String timeWindow}) =>
      _remote.fetchMyGlobalRank(timeWindow: timeWindow);

  @override
  Future<int?> fetchMyNearbyRank({
    required double radiusM,
    required String timeWindow,
  }) => _remote.fetchMyNearbyRank(radiusM: radiusM, timeWindow: timeWindow);

  @override
  Future<int?> fetchMySquadRank({
    required String squadId,
    String timeWindow = 'all_time',
  }) => _remote.fetchMySquadRank(squadId: squadId, timeWindow: timeWindow);

  @override
  Future<List<TerritoryCaptureFeedItem>> fetchRecentTerritoryCaptures({
    int rowLimit = 10,
  }) async {
    final rows = await _remote.fetchRecentTerritoryCaptures(rowLimit: rowLimit);
    return [
      for (final row in rows)
        TerritoryCaptureFeedItem(
          captureId: row['capture_id'] as String,
          winnerId: row['winner_id'] as String,
          winnerDisplayName:
              (row['winner_display_name'] as String?) ?? 'A player',
          loserId: row['loser_id'] as String?,
          loserDisplayName: row['loser_display_name'] as String?,
          areaTakenSqm: (row['area_taken_sqm'] as num?)?.toDouble() ?? 0,
          createdAt: DateTime.parse(row['created_at'] as String),
          lat: (row['lat'] as num?)?.toDouble(),
          lng: (row['lng'] as num?)?.toDouble(),
        ),
    ];
  }

  /// Latest broadcast-telemetry label per user, per squad — kept as
  /// repository-lifetime state (not per-listener) since it's meant to
  /// cheaply refresh a presence member's `activity` label between full
  /// Presence `.track()` calls (H6: Presence-for-status +
  /// Broadcast-for-telemetry split), not something each new subscriber
  /// starts blank.
  final _latestActivityBySquad = <String, Map<String, String>>{};

  @override
  Stream<List<SquadPresenceMember>> watchPresence(String squadId) {
    late final StreamController<List<SquadPresenceMember>> controller;
    List<SinglePresenceState> latestStates = const [];
    var hasStates = false;

    void emit() {
      if (!hasStates) return;
      final activityOverrides = _latestActivityBySquad[squadId] ?? const {};
      final members = <SquadPresenceMember>[];
      for (final state in latestStates) {
        for (final presence in state.presences) {
          final userId = presence.payload['user_id'] as String?;
          final displayName = presence.payload['display_name'] as String?;
          if (userId == null || displayName == null) continue;
          members.add(
            SquadPresenceMember(
              userId: userId,
              displayName: displayName,
              activity:
                  activityOverrides[userId] ??
                  presence.payload['activity'] as String?,
              avatarUrl: presence.payload['avatar_url'] as String?,
              lat: (presence.payload['lat'] as num?)?.toDouble(),
              lng: (presence.payload['lng'] as num?)?.toDouble(),
            ),
          );
        }
      }
      controller.add(members);
    }

    late final StreamSubscription<List<SinglePresenceState>> presenceSub;
    late final StreamSubscription<Map<String, dynamic>> broadcastSub;

    controller = StreamController<List<SquadPresenceMember>>.broadcast(
      onListen: () {
        presenceSub = _remote.watchPresenceState(squadId).listen((states) {
          latestStates = states;
          hasStates = true;
          emit();
        });
        broadcastSub = _remote.watchBroadcast(squadId).listen((payload) {
          final userId = payload['user_id'] as String?;
          final label = payload['label'] as String?;
          if (userId == null || label == null) return;
          (_latestActivityBySquad[squadId] ??= {})[userId] = label;
          emit();
        });
      },
      onCancel: () {
        unawaited(presenceSub.cancel());
        unawaited(broadcastSub.cancel());
      },
    );

    return controller.stream;
  }

  @override
  Future<void> trackPresence({required String activity}) async {
    final squad = _cachedSquad;
    final userId = _currentUserId;
    if (squad == null || userId == null) return;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      final displayName = profile?['display_name'] as String? ?? 'You';
      final avatarUrl = profile?['avatar_url'] as String?;
      // Best-effort — a location fetch failing/timing out (denied
      // permission, no fix yet) must never block presence tracking itself;
      // the map clustering layer that consumes this is purely optional UI.
      ({double latitude, double longitude})? position;
      try {
        position = await getIt<GetCurrentPosition>()(const NoParams());
      } catch (e) {
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Presence location fetch failed, continuing without it',
            category: 'squad.presence',
            level: SentryLevel.info,
            data: {'error': e.toString()},
          ),
        );
        position = null;
      }
      await _remote.trackPresence(squad.id, {
        'user_id': userId,
        'display_name': displayName,
        'activity': activity,
        'avatar_url': ?avatarUrl,
        if (position != null) 'lat': position.latitude,
        if (position != null) 'lng': position.longitude,
      });
    } catch (e, st) {
      // Callers (`VerificationCubit`/`RunTrackingCubit`) invoke this
      // `unawaited` — an uncaught network/RLS failure here would otherwise
      // become a silent, untracked exception in a detached future rather
      // than just skipping this one presence update.
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  @override
  void broadcastTelemetry({required String label}) {
    final squad = _cachedSquad;
    final userId = _currentUserId;
    if (squad == null || userId == null) return;

    final now = DateTime.now();
    final last = _lastBroadcastAt;
    if (last != null &&
        now.difference(last) < AppConstants.squadBroadcastThrottle) {
      return;
    }
    _lastBroadcastAt = now;

    _remote.broadcastTelemetry(squad.id, {'user_id': userId, 'label': label});
  }

  /// Used only from account sign-out/switch/delete — see
  /// `SquadRemoteDataSource.closeAllChannels`'s doc comment. Clears the
  /// in-memory squad cache too, so a stale `_cachedSquad` (and the
  /// `_fetchedOnce` guard that would otherwise prevent ever re-fetching)
  /// can't leak the outgoing identity's squad into the incoming session.
  @override
  Future<void> resetForAccountTransition() async {
    await _remote.closeAllChannels();
    _cachedSquad = null;
    _fetchedOnce = false;
    _hasEmittedOnce = false;
    _lastBroadcastAt = null;
    _latestActivityBySquad.clear();
  }

  @override
  Future<void> reportMember({
    required String reportedUserId,
    required String reason,
  }) async {
    final squad = _cachedSquad;
    final userId = _currentUserId;
    if (squad == null || userId == null) return;
    await _remote.reportMember(
      reporterId: userId,
      reportedUserId: reportedUserId,
      squadId: squad.id,
      reason: reason,
    );
  }
}
