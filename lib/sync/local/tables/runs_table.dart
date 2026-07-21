import 'package:drift/drift.dart';

/// Local mirror of the Supabase `runs` table (plan §3) — append-only log of
/// territory-capture runs (Phase 5 consumes this). `pathGeoJson` is the
/// client-simplified (RDP) path submitted to the `submit_run()` RPC; server
/// is authoritative for `areaSqm`/`integrityVerdict` and pushes them back
/// down via a subsequent pull/realtime update to this same row.
@DataClassName('RunRow')
class Runs extends Table {
  TextColumn get id => text()(); // client-generated UUIDv4
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get pointCount => integer()();
  TextColumn get pathGeoJson => text()();
  RealColumn get areaSqm => real().nullable()();
  TextColumn get integrityVerdict => text().nullable()();
  TextColumn get rejectedReason => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
