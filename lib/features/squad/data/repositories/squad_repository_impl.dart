import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_presence_member.dart';
import '../../domain/entities/streak_tier.dart';
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
  Squad? _cachedSquad;
  bool _fetchedOnce = false;
  bool _hasEmittedOnce = false;

  DateTime? _lastBroadcastAt;
  static const _broadcastThrottle = Duration(seconds: 3);

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
  /// `SquadStatus.loading`). Fails open to "no squad" on any error/timeout
  /// rather than hanging; the create/join flow is always reachable from
  /// that empty state, so failing open costs nothing but is far better
  /// than an unrecoverable spinner.
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
          .timeout(const Duration(seconds: 10));
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
          .timeout(const Duration(seconds: 10));
      _emitSquad(row == null ? null : _squadFromJson(row));
    } catch (_) {
      _emitSquad(null);
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

  @override
  Stream<List<LeaderboardEntry>> watchLeaderboard(String squadId) async* {
    final userId = _currentUserId;
    while (true) {
      // A single failed poll must not kill the whole stream (an unhandled
      // error here would terminate the `async*` generator entirely,
      // silently ending the leaderboard for the rest of the session) —
      // skip this round and retry on the next tick instead.
      try {
        final rows = await _remote.fetchLeaderboard(squadId).timeout(const Duration(seconds: 10));
        yield [
          for (var i = 0; i < rows.length; i++)
            LeaderboardEntry(
              rank: i + 1,
              userId: rows[i]['user_id'] as String,
              displayName: (rows[i]['display_name'] as String?) ?? 'Squad member',
              streakTier: StreakTier.fromValue((rows[i]['streak_tier'] as num?)?.toInt() ?? 0),
              areaSqm: (rows[i]['area_sqm'] as num?)?.toDouble() ?? 0,
              isYou: rows[i]['user_id'] == userId,
            ),
        ];
      } catch (_) {
        // no-op — retry next tick
      }
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }

  @override
  Stream<List<SquadPresenceMember>> watchPresence(String squadId) {
    return _remote.watchPresenceState(squadId).map((states) {
      final members = <SquadPresenceMember>[];
      for (final state in states) {
        for (final presence in state.presences) {
          final userId = presence.payload['user_id'] as String?;
          final displayName = presence.payload['display_name'] as String?;
          if (userId == null || displayName == null) continue;
          members.add(
            SquadPresenceMember(
              userId: userId,
              displayName: displayName,
              activity: presence.payload['activity'] as String?,
            ),
          );
        }
      }
      return members;
    });
  }

  @override
  Future<void> trackPresence({required String activity}) async {
    final squad = _cachedSquad;
    final userId = _currentUserId;
    if (squad == null || userId == null) return;
    final displayName =
        (await _supabase.from('profiles').select('display_name').eq('id', userId).maybeSingle())?['display_name']
            as String? ??
        'You';
    await _remote.trackPresence(squad.id, {'user_id': userId, 'display_name': displayName, 'activity': activity});
  }

  @override
  void broadcastTelemetry({required String label}) {
    final squad = _cachedSquad;
    final userId = _currentUserId;
    if (squad == null || userId == null) return;

    final now = DateTime.now();
    final last = _lastBroadcastAt;
    if (last != null && now.difference(last) < _broadcastThrottle) return;
    _lastBroadcastAt = now;

    _remote.broadcastTelemetry(squad.id, {'user_id': userId, 'label': label});
  }
}
