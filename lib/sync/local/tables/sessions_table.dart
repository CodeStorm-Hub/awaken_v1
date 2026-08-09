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
  // JSON-encoded `[{"offset_ms": int, "angle_deg": double}, ...]` captured
  // at each confirmed rep — same "jsonb as a local text column" convention
  // as `Runs.pathGeoJson`. Submitted to `complete_workout_session()`, which
  // computes the two columns below server-side (mirrors `Runs
  // .integrityVerdict`/`.rejectedReason`); never client-writable evidence
  // of "this row is trustworthy," just the raw evidence.
  TextColumn get repTraceJson => text().nullable()();
  TextColumn get integrityVerdict => text().nullable()();
  TextColumn get rejectedReason => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
