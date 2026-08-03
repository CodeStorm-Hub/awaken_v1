import 'package:drift/drift.dart';

/// Client-only outbox (plan §3, ADR-002): every writeable-entity mutation
/// enqueues exactly one row here in the same Drift transaction as the
/// domain write (see `LocalWriter`). `nextAttemptAt` models backoff as a
/// scheduled time rather than a sleep, so the worker can be a simple
/// connectivity-triggered poll instead of holding timers per entry.
@DataClassName('OutboxEntryRow')
@TableIndex(name: 'sync_outbox_next_attempt_at_idx', columns: {#nextAttemptAt})
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTable => text()(); // 'alarms' | 'sessions' | 'runs'
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // 'upsert' | 'delete'
  TextColumn get payload => text()(); // JSON-encoded row for upsert; empty for delete
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// Dead-letter classification: `'transient'` (network/timeout — keep
  /// retrying with backoff) vs `'permanent'` (4xx/constraint violation —
  /// the same payload will never succeed, so `SyncWorker` stops retrying
  /// once `attemptCount` reaches [maxAttempts] and instead surfaces it via
  /// `SyncStatus.error`). Null until the first failure.
  TextColumn get errorType => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get maxAttempts => integer().withDefault(const Constant(10))();
}
