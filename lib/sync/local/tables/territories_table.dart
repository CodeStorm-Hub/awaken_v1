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

  @override
  Set<Column> get primaryKey => {id};
}
