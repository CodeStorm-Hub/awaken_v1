import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/alarms_table.dart';
import 'tables/runs_table.dart';
import 'tables/sessions_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/territories_table.dart';
import 'tables/user_stats_table.dart';

part 'database.g.dart';

/// The app's single source of truth (plan §3 — "sync engine ownership").
/// Opened once via `register_module.dart` (injectable can't construct a
/// `QueryExecutor` itself) and injected everywhere as `AppDatabase`.
@DriftDatabase(tables: [Alarms, Sessions, Runs, Territories, SyncOutbox, UserStats])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(alarms, alarms.recurringDays);
            await m.createTable(userStats);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'awaken.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
