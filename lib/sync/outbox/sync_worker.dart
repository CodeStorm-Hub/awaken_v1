import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../connectivity/connectivity_watcher.dart';
import '../local/database.dart';
import '../sync_status.dart';
import 'outbox_operation.dart';

/// Connectivity-triggered outbox drain with `next_attempt_at` backoff (plan
/// §3, ADR-002). One drain loop runs at a time; a trigger that arrives
/// mid-drain is a no-op — the next connectivity event or explicit call
/// picks up whatever is still due.
@lazySingleton
class SyncWorker {
  SyncWorker(this._db, this._supabase, this._connectivity);

  final AppDatabase _db;
  final SupabaseClient _supabase;
  final ConnectivityWatcher _connectivity;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _statusController.stream;

  StreamSubscription<bool>? _connectivitySub;
  bool _draining = false;

  /// Starts listening for connectivity changes and attempts an initial
  /// drain. Call once from bootstrap after DI is configured.
  void start() {
    _connectivitySub ??= _connectivity.onlineChanges.listen((online) {
      if (online) {
        unawaited(drainOutbox());
      } else {
        _statusController.add(SyncStatus.offline);
      }
    });
    unawaited(drainOutbox());
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _statusController.close();
  }

  Future<void> drainOutbox() async {
    if (_draining) return;
    _draining = true;
    try {
      if (!await _connectivity.isOnline) {
        _statusController.add(SyncStatus.offline);
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return; // no session yet — retried on the next trigger

      final now = DateTime.now();
      final due = await (_db.select(_db.syncOutbox)
            ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(now))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      if (due.isEmpty) {
        _statusController.add(SyncStatus.idle);
        return;
      }

      _statusController.add(SyncStatus.syncing);
      var hadFailure = false;
      for (final entry in due) {
        try {
          await _push(entry, userId);
          await (_db.delete(_db.syncOutbox)..where((t) => t.id.equals(entry.id))).go();
        } catch (_) {
          hadFailure = true;
          await _applyBackoff(entry);
        }
      }
      _statusController.add(hadFailure ? SyncStatus.error : SyncStatus.idle);
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

  Future<void> _applyBackoff(OutboxEntryRow entry) async {
    final attempt = entry.attemptCount + 1;
    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(entry.id))).write(
      SyncOutboxCompanion(
        attemptCount: Value(attempt),
        nextAttemptAt: Value(DateTime.now().add(_backoffDelay(attempt))),
      ),
    );
  }

  Duration _backoffDelay(int attempt) {
    final scaled = AppConstants.syncInitialBackoff * (1 << attempt.clamp(0, 10));
    return scaled > AppConstants.syncMaxBackoff ? AppConstants.syncMaxBackoff : scaled;
  }
}
