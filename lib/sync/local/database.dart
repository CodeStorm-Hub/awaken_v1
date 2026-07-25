import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/alarms_table.dart';
import 'tables/run_checkpoints_table.dart';
import 'tables/runs_table.dart';
import 'tables/sessions_table.dart';
import 'tables/sync_meta_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/territories_table.dart';
import 'tables/user_stats_table.dart';

part 'database.g.dart';

/// The app's single source of truth (plan §3 — "sync engine ownership").
/// Opened once via `register_module.dart` (injectable can't construct a
/// `QueryExecutor` itself) and injected everywhere as `AppDatabase`.
@DriftDatabase(
  tables: [Alarms, Sessions, Runs, Territories, SyncOutbox, UserStats, RunCheckpoints, SyncMeta],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(alarms, alarms.recurringDays);
            await m.createTable(userStats);
          }
          if (from < 3) {
            await m.addColumn(runs, runs.isClosedLoop);
            await m.addColumn(runs, runs.capturedAreaSqm);
          }
          if (from < 4) {
            await m.addColumn(alarms, alarms.nativeId);
          }
          if (from < 5) {
            await m.addColumn(runs, runs.pointTimestampsJson);
          }
          if (from < 6) {
            await m.createTable(runCheckpoints);
          }
          if (from < 7) {
            await m.addColumn(territories, territories.deletedAt);
            await m.addColumn(syncOutbox, syncOutbox.errorType);
            await m.addColumn(syncOutbox, syncOutbox.lastError);
            await m.addColumn(syncOutbox, syncOutbox.maxAttempts);
            await m.createTable(syncMeta);
            await m.createIndex(syncOutboxNextAttemptAtIdx);
          }
        },
      );

  /// Wipes every locally-cached row. This DB has no per-row `user_id`
  /// scoping — it's a single cache of "whichever identity is currently
  /// signed in," not a multi-tenant store — so switching identities
  /// (sign-out, delete-account, or a new anonymous session starting up
  /// afterwards) without clearing it first leaks the previous identity's
  /// alarms/runs/territories into the next one, and the outbox would try
  /// to push the old identity's pending writes under the new one's
  /// `user_id`. Call this right before/after ending a Supabase session.
  Future<void> clearAllLocalData() {
    return transaction(() async {
      await delete(syncOutbox).go();
      await delete(sessions).go();
      await delete(runs).go();
      await delete(territories).go();
      await delete(alarms).go();
      await delete(userStats).go();
      await delete(runCheckpoints).go();
      await delete(syncMeta).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'awaken.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
