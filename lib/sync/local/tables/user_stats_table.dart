import 'package:drift/drift.dart';

/// Single-row local cache of the Supabase `user_stats` table — per-user
/// stats that aren't tied to any one entity, currently just the wake-up
/// tax multiplier (plan discussion: the tax was moved off individual
/// alarms to a global, per-user value so deleting/recreating an alarm
/// can't reset it). Synced via `LocalWriter.upsertUserStats` — see
/// `WakeUpTaxStore`.
@DataClassName('UserStatsRow')
class UserStats extends Table {
  /// Always `1` — this table only ever holds one row (single-user,
  /// on-device). Simpler than a nullable/singleton-lookup pattern.
  IntColumn get id => integer().withDefault(const Constant(1))();
  RealColumn get currentTaxMultiplier => real().withDefault(const Constant(1.0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
