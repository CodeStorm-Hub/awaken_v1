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

  /// JSON array of per-point ISO8601 capture timestamps, same order as
  /// `pathGeoJson`'s coordinates. Sent to `submit_run()`'s
  /// `p_point_timestamps` param so the server can validate per-segment
  /// speed (P0 anti-cheat finding — the RPC couldn't do this at all
  /// without per-point timing, since `pathGeoJson` alone carries no time
  /// information). Nullable for rows written before this column existed.
  TextColumn get pointTimestampsJson => text().nullable()();
  BoolColumn get isClosedLoop => boolean().withDefault(const Constant(false))();
  /// This run's own captured polygon area — what `submit_run()` returns as
  /// `captured_area_sqm` (the celebration-UI "delta"), distinct from
  /// `areaSqm` (the user's total territory area after server-side merge).
  RealColumn get capturedAreaSqm => real().nullable()();
  RealColumn get areaSqm => real().nullable()();
  TextColumn get integrityVerdict => text().nullable()();
  TextColumn get rejectedReason => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
