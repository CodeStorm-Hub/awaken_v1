import 'package:drift/drift.dart';

/// Local read-only cache of the Supabase `territories` table (plan §3).
/// Territory rows are server-authoritative — mutated only by the
/// `submit_run()` `SECURITY DEFINER` RPC — so this table is populated by
/// pull/realtime sync only and never has a `sync_outbox` entry of its own.
@DataClassName('TerritoryRow')
class Territories extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get geoJson => text()();
  RealColumn get areaSqm => real()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Local-only tombstone (mirrors the backend's soft-delete column, but
  /// this cache never round-trips it) — set when a refresh's bbox query no
  /// longer returns a previously-cached row inside that same bbox
  /// (decayed, captured to nothing, or otherwise removed server-side).
  /// Kept rather than hard-deleting immediately so a row that reappears in
  /// a later refresh (e.g. recaptured) can simply have this cleared.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
