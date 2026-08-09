import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps the 5 squad RPCs (`create_squad`/`join_squad`/`leave_squad`/
/// `squad_leaderboard`/`squad_members`, all `SECURITY DEFINER` — squad-mate
/// visibility goes through these, never relaxed `profiles` RLS) and owns
/// the one Realtime channel per squad (Presence + Broadcast, per H6).
@lazySingleton
class SquadRemoteDataSource {
  SquadRemoteDataSource(this._supabase);

  final SupabaseClient _supabase;

  final _channels = <String, RealtimeChannel>{};
  final _channelRefCounts = <String, int>{};

  /// Completes once a channel's `subscribe()` call reports `subscribed` —
  /// awaited by `trackPresence`/`broadcastTelemetry` so a `.track()`/
  /// `.sendBroadcastMessage()` call can't race the initial join and get
  /// silently dropped before the channel is actually joined.
  final _subscribed = <String, Completer<void>>{};

  /// Squad ids this device currently has Presence `.track()`ed on — a
  /// standing retain, released only on `closeAllChannels()`, since an
  /// active `track()` payload is live channel state that must survive
  /// regardless of whether anything is currently *watching* presence.
  /// Without this, `watchPresenceState`'s own ref-count could drop to zero
  /// and tear the channel down (silently untracking this device) while it
  /// was still meant to show as present.
  final _trackedSquadIds = <String>{};

  Future<Map<String, dynamic>> createSquad(String name) async {
    final result = await _supabase.rpc(
      'create_squad',
      params: {'p_name': name},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> joinSquad(String inviteCode) async {
    final result = await _supabase.rpc(
      'join_squad',
      params: {'p_invite_code': inviteCode},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> leaveSquad() => _supabase.rpc('leave_squad');

  Future<void> reportMember({
    required String reporterId,
    required String reportedUserId,
    required String squadId,
    required String reason,
  }) {
    return _supabase.from('squad_reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'squad_id': squadId,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard(String squadId) async {
    final result = await _supabase.rpc(
      'squad_leaderboard',
      params: {'p_squad_id': squadId},
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// [timeWindow] is `'all_time'`, `'weekly'`, or `'daily'` (matches the
  /// RPCs' `p_time_window` check constraint). [rowLimit] is `p_row_limit`
  /// (1-500). [offset] is `p_offset` (>= 0) — both RPCs gained a true
  /// offset/cursor param, so "load more" pages via [offset] rather than
  /// refetching with a larger [rowLimit].
  Future<List<Map<String, dynamic>>> fetchNearbyLeaderboard({
    required double radiusM,
    required String timeWindow,
    int rowLimit = 50,
    int offset = 0,
  }) async {
    final result = await _supabase.rpc(
      'nearby_leaderboard',
      params: {
        'p_radius_m': radiusM,
        'p_time_window': timeWindow,
        'p_row_limit': rowLimit,
        'p_offset': offset,
      },
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchGlobalLeaderboard({
    required String timeWindow,
    int rowLimit = 50,
    int offset = 0,
  }) async {
    final result = await _supabase.rpc(
      'global_leaderboard',
      params: {
        'p_time_window': timeWindow,
        'p_row_limit': rowLimit,
        'p_offset': offset,
      },
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Caller's own rank — independent targeted query backing the leaderboard
  /// sheet's pinned "You: #N" row (`my_global_rank`/`my_nearby_rank` RPCs,
  /// added alongside the leaderboard sheet's pagination/pinned-row rework).
  Future<int?> fetchMyGlobalRank({required String timeWindow}) async {
    final result = await _supabase.rpc(
      'my_global_rank',
      params: {'p_time_window': timeWindow},
    );
    return (result as num?)?.toInt();
  }

  Future<int?> fetchMyNearbyRank({
    required double radiusM,
    required String timeWindow,
  }) async {
    final result = await _supabase.rpc(
      'my_nearby_rank',
      params: {'p_radius_m': radiusM, 'p_time_window': timeWindow},
    );
    return (result as num?)?.toInt();
  }

  /// Caller's own rank within a specific squad (`my_squad_rank` RPC) — backs
  /// the weekly-reset ceremony's squad-scoped rank display, mirroring
  /// [fetchMyGlobalRank]/[fetchMyNearbyRank]'s shape.
  Future<int?> fetchMySquadRank({
    required String squadId,
    String timeWindow = 'all_time',
  }) async {
    final result = await _supabase.rpc(
      'my_squad_rank',
      params: {'p_squad_id': squadId, 'p_time_window': timeWindow},
    );
    return (result as num?)?.toInt();
  }

  /// "Conquest ticker" recent-captures feed (`recent_territory_captures`
  /// RPC) — bypasses `territory_captures`' own select-own RLS via a
  /// SECURITY DEFINER function, same public-aggregate posture as the
  /// leaderboard RPCs.
  Future<List<Map<String, dynamic>>> fetchRecentTerritoryCaptures({
    int rowLimit = 10,
  }) async {
    final result = await _supabase.rpc(
      'recent_territory_captures',
      params: {'p_row_limit': rowLimit},
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Membership roster (`squad_members`) joined with live Realtime Presence
  /// state — "Live now" only shows members who are actually online.
  RealtimeChannel _channelFor(String squadId) {
    return _channels.putIfAbsent(squadId, () {
      // Private (P0 fix): without this, the channel had no
      // `realtime.messages` authorization at all — any client (including
      // an unrelated squad's members) could subscribe and read/send
      // Presence & Broadcast traffic. Gated server-side by the
      // "squad members can use their squad's realtime channel" RLS policy
      // on `realtime.messages` (migration
      // `squad_realtime_authorization`), keyed off `profiles.squad_id`.
      final channel = _supabase.channel(
        'squad:$squadId',
        opts: const RealtimeChannelConfig(private: true),
      );
      _channelRefCounts[squadId] = 0;
      final completer = Completer<void>();
      _subscribed[squadId] = completer;
      // `subscribe()` may only be called once per channel instance (it
      // throws on a second call) — do it exactly once here, at creation,
      // rather than at each call site that wants presence/broadcast.
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !completer.isCompleted) {
          completer.complete();
        }
      });
      return channel;
    });
  }

  Future<void> _awaitSubscribed(String squadId) {
    _channelFor(squadId);
    return _subscribed[squadId]!.future;
  }

  void _retain(String squadId) {
    _channelRefCounts[squadId] = (_channelRefCounts[squadId] ?? 0) + 1;
  }

  void _release(String squadId) {
    final count = (_channelRefCounts[squadId] ?? 1) - 1;
    if (count > 0) {
      _channelRefCounts[squadId] = count;
      return;
    }
    final channel = _channels.remove(squadId);
    _channelRefCounts.remove(squadId);
    _subscribed.remove(squadId);
    if (channel != null) unawaited(_supabase.removeChannel(channel));
  }

  /// Presence sync/join/leave, forwarded as the full current presence-state
  /// snapshot each time (simpler for the repository to map than tracking
  /// diffs itself).
  Stream<List<SinglePresenceState>> watchPresenceState(String squadId) {
    _retain(squadId);
    final channel = _channelFor(squadId);
    late final StreamController<List<SinglePresenceState>> controller;

    void emitCurrentState() => controller.add(channel.presenceState());

    controller = StreamController<List<SinglePresenceState>>.broadcast(
      onCancel: () => _release(squadId),
    );

    channel
      ..onPresenceSync((_) => emitCurrentState())
      ..onPresenceJoin((_) => emitCurrentState())
      ..onPresenceLeave((_) => emitCurrentState());

    return controller.stream;
  }

  Future<void> trackPresence(
    String squadId,
    Map<String, dynamic> payload,
  ) async {
    if (_trackedSquadIds.add(squadId)) _retain(squadId);
    await _awaitSubscribed(squadId);
    await _channelFor(squadId).track(payload);
  }

  static const _broadcastEvent = 'telemetry';

  void broadcastTelemetry(String squadId, Map<String, dynamic> payload) {
    unawaited(() async {
      try {
        await _awaitSubscribed(squadId);
        await _channelFor(
          squadId,
        ).sendBroadcastMessage(event: _broadcastEvent, payload: payload);
      } catch (e, st) {
        // Fire-and-forget by design (the caller doesn't await this), but a
        // dropped channel/failed subscribe must not become a silent,
        // untracked unhandled exception in a detached future — see
        // `trackPresence`'s repository-level location-fetch catch for the
        // same reasoning.
        unawaited(Sentry.captureException(e, stackTrace: st));
      }
    }());
  }

  /// Live telemetry from squadmates' `broadcastTelemetry` calls — each
  /// event's raw payload (`{user_id, label}`) is forwarded as-is; the
  /// repository maps it onto presence members.
  Stream<Map<String, dynamic>> watchBroadcast(String squadId) {
    _retain(squadId);
    final channel = _channelFor(squadId);
    late final StreamController<Map<String, dynamic>> controller;
    controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () => _release(squadId),
    );
    channel.onBroadcast(
      event: _broadcastEvent,
      callback: (payload) => controller.add(Map<String, dynamic>.from(payload)),
    );
    return controller.stream;
  }

  /// Force-closes every open squad channel regardless of ref count — used
  /// only from account sign-out/switch/delete, where the outgoing
  /// identity's live Presence/Broadcast subscriptions must not survive
  /// into the next session (private channels are authorized per-`auth.uid()`
  /// via the `realtime.messages` RLS policy, so a stale subscription would
  /// simply stop receiving traffic once the JWT changes — but leaving it
  /// open leaks a connection and, worse, could still hold the *old* squad's
  /// presence/track state client-side across the identity swap).
  Future<void> closeAllChannels() async {
    final channels = _channels.values.toList();
    _channels.clear();
    _channelRefCounts.clear();
    _trackedSquadIds.clear();
    _subscribed.clear();
    await Future.wait(channels.map(_supabase.removeChannel));
  }
}
