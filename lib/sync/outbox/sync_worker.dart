import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../connectivity/connectivity_watcher.dart';
import '../local/database.dart';
import '../pull/pull_down_sync.dart';
import '../sync_status.dart';
import 'outbox_operation.dart';

/// Connectivity-triggered outbox drain with `next_attempt_at` backoff (plan
/// §3, ADR-002). One drain loop runs at a time; a trigger that arrives
/// mid-drain is a no-op — the next connectivity event or explicit call
/// picks up whatever is still due.
@lazySingleton
class SyncWorker {
  SyncWorker(this._db, this._supabase, this._connectivity, this._pullDownSync);

  final AppDatabase _db;
  final SupabaseClient _supabase;
  final ConnectivityWatcher _connectivity;
  final PullDownSync _pullDownSync;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _lastStatus = SyncStatus.idle;

  /// Replays the current status to a new subscriber before continuing with
  /// live updates — a plain broadcast stream doesn't replay past events, so
  /// a UI that only just opened (e.g. `TerritoryPage`, mounted well after
  /// the last drain cycle) would otherwise show nothing until the *next*
  /// status change, even while a sync failure or backlog is sitting there
  /// right now. Same class of bug as `SquadRepositoryImpl._mySquadController`
  /// (see engineering_gotchas memory) — this stream had never been consumed
  /// by any UI at all before, so it hadn't been hit yet.
  Stream<SyncStatus> get status async* {
    yield _lastStatus;
    yield* _statusController.stream;
  }

  void _emitStatus(SyncStatus status) {
    _lastStatus = status;
    _statusController.add(status);
  }

  StreamSubscription<bool>? _connectivitySub;
  Timer? _wakeTimer;
  bool _draining = false;
  bool _paused = false;

  /// Belt-and-suspenders wake-up for entries whose backoff `nextAttemptAt`
  /// elapses with no connectivity *change* to trigger a drain (the previous
  /// design only ever drained on a connectivity toggle or app start, so a
  /// backed-off entry could sit past its due time indefinitely on a
  /// connection that never flaps). A coarse period is fine — this is a
  /// safety net, not the primary trigger.
  static const _wakeInterval = Duration(seconds: 60);

  /// Starts listening for connectivity changes and attempts an initial
  /// drain. Call once from bootstrap after DI is configured.
  void start() {
    _connectivitySub ??= _connectivity.onlineChanges.listen((online) {
      if (online) {
        unawaited(drainOutbox());
      } else {
        _emitStatus(SyncStatus.offline);
      }
    });
    _wakeTimer ??= Timer.periodic(_wakeInterval, (_) => unawaited(drainOutbox()));
    unawaited(drainOutbox());
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _wakeTimer?.cancel();
    await _statusController.close();
  }

  /// Runs [transition] with the outbox drain loop held off, so an
  /// account sign-out/switch/delete's `clearAllLocalData()` wipe can't race
  /// an in-flight `drainOutbox()` reading/writing the same tables. Any
  /// drain already in progress when this is called is allowed to finish
  /// first (it already holds `_draining`); no new drain can start until
  /// [transition] completes.
  Future<T> pauseFor<T>(Future<T> Function() transition) async {
    _paused = true;
    try {
      while (_draining) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return await transition();
    } finally {
      _paused = false;
    }
  }

  /// [skipConnectivityCheck] bypasses the `ConnectivityWatcher.isOnline`
  /// pre-check (a local OS connectivity-plugin read — reachable network
  /// interface, not actual Supabase reachability). That check is a cheap
  /// optimization for the periodic/connectivity-triggered background drain
  /// (avoid a doomed attempt while genuinely offline), but `connectivity_plus`
  /// can report a stale/false `none` right after a network transition — a
  /// real bug found live: a user closed a loop with good connectivity, but
  /// `RunTrackingRepositoryImpl.captureRun()`'s synchronous best-effort push
  /// (right after the run is saved, while the user is actively watching)
  /// hit this false negative and silently fell through to the "will sync
  /// once back online" pending state despite being online the whole time —
  /// the captured territory never appeared. `captureRun()` now passes
  /// `skipConnectivityCheck: true` for that call: attempt the real network
  /// call directly rather than trusting the local heuristic first. A
  /// genuinely offline attempt still fails fast (`SocketException`,
  /// classified transient) and falls back to the normal backoff/retry path
  /// — no worse than before in that case, just one extra failed round trip.
  Future<void> drainOutbox({bool skipConnectivityCheck = false}) async {
    if (_draining || _paused) return;
    _draining = true;
    try {
      if (!skipConnectivityCheck && !await _connectivity.isOnline) {
        _emitStatus(SyncStatus.offline);
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return; // no session yet — retried on the next trigger

      // Incremental remote→local convergence (plan: "replace one-time pull
      // hydration") — runs every drain cycle, not just once at bootstrap.
      // Best-effort: a pull failure must not block the push half of this
      // cycle, and vice versa.
      try {
        await _pullDownSync.run();
      } catch (_) {
        // Retried next cycle.
      }

      final now = DateTime.now();
      // Ordered by entity first: entries for the same (table, id) must push
      // in creation order (an older upsert landing after a newer one would
      // resurrect stale data), and once one of an entity's entries fails,
      // every later entry for that same entity is skipped this pass rather
      // than raced ahead of it out of order. `LIMIT` bounds one drain pass
      // so a huge backlog can't block the loop for an unbounded time.
      final due = await (_db.select(_db.syncOutbox)
            ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(now))
            ..orderBy([
              (t) => OrderingTerm.asc(t.entityTable),
              (t) => OrderingTerm.asc(t.entityId),
              (t) => OrderingTerm.asc(t.createdAt),
            ])
            ..limit(100))
          .get();

      if (due.isEmpty) {
        _emitStatus(SyncStatus.idle);
        return;
      }

      _emitStatus(SyncStatus.syncing);
      var hadFailure = false;
      final failedEntities = <String>{};
      for (final entry in due) {
        final entityKey = '${entry.entityTable}:${entry.entityId}';
        if (failedEntities.contains(entityKey)) continue;
        try {
          await _push(entry, userId);
          await (_db.delete(_db.syncOutbox)..where((t) => t.id.equals(entry.id))).go();
        } catch (e) {
          hadFailure = true;
          failedEntities.add(entityKey);
          await _applyFailure(entry, e);
        }
      }
      _emitStatus(hadFailure ? SyncStatus.error : SyncStatus.idle);
    } finally {
      _draining = false;
    }
  }

  Future<void> _push(OutboxEntryRow entry, String userId) async {
    if (entry.entityTable == 'runs' && entry.operation == OutboxOperation.upsert.name) {
      // `runs.path` is PostGIS geometry — a raw GeoJSON-string upsert would
      // not auto-cast. Runs are submitted through `submit_run()` instead of
      // a generic table upsert; this is the offline-retry path for
      // `RunTrackingRepositoryImpl.captureRun()`'s online happy path.
      await _pushRun(entry);
      return;
    }
    if (entry.entityTable == 'user_stats' && entry.operation == OutboxOperation.upsert.name) {
      // `current_tax_multiplier` is no longer client-writable (P0 fix — it
      // was previously client-authoritative). The server recomputes it via
      // one of two RPCs instead of accepting a raw upsert; see
      // `LocalWriter.upsertUserStats`.
      await _pushUserStats(entry);
      return;
    }
    final table = _supabase.from(entry.entityTable);
    if (entry.operation == OutboxOperation.delete.name) {
      await table.update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', entry.entityId);
      return;
    }
    final payload = Map<String, Object?>.from(jsonDecode(entry.payload) as Map)
      ..['user_id'] = userId;
    await table.upsert(payload);
  }

  Future<void> _pushRun(OutboxEntryRow entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, Object?>;
    final pointTimestampsJson = payload['point_timestamps'] as String?;
    final result = await _supabase.rpc<Object?>(
      'submit_run',
      params: {
        'p_run_id': payload['id'],
        'p_path': jsonDecode(payload['path'] as String),
        'p_started_at': payload['started_at'],
        'p_ended_at': payload['ended_at'] ?? payload['started_at'],
        // Enables the server's per-segment speed/teleport check (P0
        // anti-cheat finding) — null for rows queued before this field
        // existed, which the RPC treats as "skip the per-segment check,
        // aggregate speed gate still applies".
        if (pointTimestampsJson != null) 'p_point_timestamps': jsonDecode(pointTimestampsJson),
      },
    );
    final response = Map<String, Object?>.from(result! as Map);
    await (_db.update(_db.runs)..where((t) => t.id.equals(payload['id'] as String))).write(
      RunsCompanion(
        isClosedLoop: Value(response['closed_loop'] as bool? ?? false),
        capturedAreaSqm: Value((response['captured_area_sqm'] as num?)?.toDouble()),
        areaSqm: Value((response['territory_area_sqm'] as num?)?.toDouble()),
        bonusAreaSqm: Value((response['bonus_area_sqm'] as num?)?.toDouble()),
        bountyMultiplier: Value((response['bounty_multiplier'] as num?)?.toDouble()),
        integrityVerdict: Value(response['accepted'] == true ? 'trusted' : 'rejected'),
        rejectedReason: Value(response['reason'] as String?),
      ),
    );
  }

  Future<void> _pushUserStats(OutboxEntryRow entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, Object?>;
    final rpc = payload['action'] == 'reset' ? 'reset_wake_up_tax' : 'bump_wake_up_tax';
    final result = await _supabase.rpc<Object?>(rpc);
    final authoritative = (result as num).toDouble();
    // Reconcile the local cache with the server's authoritative value —
    // this can legitimately differ from what was locally computed if
    // another device pushed a bump/reset first.
    await (_db.update(_db.userStats)..where((t) => t.id.equals(1))).write(
      UserStatsCompanion(currentTaxMultiplier: Value(authoritative)),
    );
  }

  /// `'permanent'` (a constraint violation, permission error, or malformed
  /// request — the identical payload will fail identically forever) vs
  /// `'transient'` (network/timeout — worth retrying). Postgres/PostgREST
  /// error codes: `22xxx`/`23xxx` are data/integrity errors, `2565`/`42501`
  /// permission errors, `PGRST` codes are PostgREST request-shape errors —
  /// none of those change on retry. Anything else (including plain
  /// `SocketException`/`TimeoutException` with no `.code` at all) is
  /// treated as transient, the safe default when the cause is ambiguous.
  String _classifyError(Object error) {
    if (error is SocketException || error is TimeoutException) return 'transient';
    final code = (error is PostgrestException) ? error.code : null;
    if (code == null) return 'transient';
    if (code.startsWith('22') ||
        code.startsWith('23') ||
        code == '42501' ||
        code.startsWith('PGRST')) {
      return 'permanent';
    }
    return 'transient';
  }

  Future<void> _applyFailure(OutboxEntryRow entry, Object error) async {
    final attempt = entry.attemptCount + 1;
    final errorType = _classifyError(error);
    final deadLettered = errorType == 'permanent' || attempt >= entry.maxAttempts;
    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(entry.id))).write(
      SyncOutboxCompanion(
        attemptCount: Value(attempt),
        errorType: Value(errorType),
        lastError: Value(error.toString()),
        // A dead-lettered entry is pushed far into the future rather than
        // deleted — deleting would silently drop a real mutation with no
        // record of it ever existing; this way it simply stops competing
        // for retry slots until a future "review failed syncs" UI clears
        // or resets it.
        nextAttemptAt: Value(
          deadLettered ? DateTime.now().add(const Duration(days: 3650)) : DateTime.now().add(_backoffDelay(attempt)),
        ),
      ),
    );
  }

  Duration _backoffDelay(int attempt) {
    // `attempt` is 1-indexed (the first failure passes `attempt: 1`), so
    // `1 << (attempt - 1)` gives 1x/2x/4x/... — the first retry waits
    // exactly `syncInitialBackoff`, not double it.
    final scaled = AppConstants.syncInitialBackoff * (1 << (attempt - 1).clamp(0, 10));
    return scaled > AppConstants.syncMaxBackoff ? AppConstants.syncMaxBackoff : scaled;
  }
}
