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
    final table = _supabase.from(entry.entityTable);
    if (entry.operation == OutboxOperation.delete.name) {
      await table.update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', entry.entityId);
      return;
    }
    final payload = Map<String, Object?>.from(jsonDecode(entry.payload) as Map)
      ..['user_id'] = userId;
    await table.upsert(payload);
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
