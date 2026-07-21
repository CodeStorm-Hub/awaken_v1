import 'package:drift/drift.dart';

/// Local mirror of the Supabase `sessions` table (plan §3) — append-only log
/// of completed/skipped verification sessions (Phase 4 consumes this).
@DataClassName('SessionRow')
class Sessions extends Table {
  TextColumn get id => text()(); // client-generated UUIDv4
  TextColumn get alarmId => text().nullable()();
  TextColumn get exerciseMode => text()();
  IntColumn get repsCompleted => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
