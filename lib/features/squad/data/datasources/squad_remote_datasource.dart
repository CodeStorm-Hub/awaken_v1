import 'dart:async';

import 'package:injectable/injectable.dart';
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

  Future<Map<String, dynamic>> createSquad(String name) async {
    final result = await _supabase.rpc('create_squad', params: {'p_name': name});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> joinSquad(String inviteCode) async {
    final result = await _supabase.rpc('join_squad', params: {'p_invite_code': inviteCode});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> leaveSquad() => _supabase.rpc('leave_squad');

  Future<List<Map<String, dynamic>>> fetchLeaderboard(String squadId) async {
    final result = await _supabase.rpc('squad_leaderboard', params: {'p_squad_id': squadId});
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Membership roster (`squad_members`) joined with live Realtime Presence
  /// state — "Live now" only shows members who are actually online.
  RealtimeChannel _channelFor(String squadId) {
    return _channels.putIfAbsent(squadId, () {
      final channel = _supabase.channel('squad:$squadId');
      _channelRefCounts[squadId] = 0;
      // `subscribe()` may only be called once per channel instance (it
      // throws on a second call) — do it exactly once here, at creation,
      // rather than at each call site that wants presence/broadcast.
      channel.subscribe();
      return channel;
    });
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

  Future<void> trackPresence(String squadId, Map<String, dynamic> payload) async {
    await _channelFor(squadId).track(payload);
  }

  static const _broadcastEvent = 'telemetry';

  void broadcastTelemetry(String squadId, Map<String, dynamic> payload) {
    unawaited(_channelFor(squadId).sendBroadcastMessage(event: _broadcastEvent, payload: payload));
  }
}
