import 'package:drift/drift.dart';

/// Local mirror of the Supabase `alarms` table (plan §3) — cross-device
/// backup/sync of the schedule. The `alarm` package (native scheduling
/// engine) remains the source of truth for *ringing behavior*; this table
/// exists only so a signed-in user's alarms survive a reinstall/new device.
@DataClassName('AlarmRow')
class Alarms extends Table {
  TextColumn get id => text()(); // client-generated UUIDv4
  DateTimeColumn get scheduledTime => dateTime()();
  TextColumn get exerciseMode => text()();
  IntColumn get requiredReps => integer()();
  RealColumn get penaltyMultiplier => real().withDefault(const Constant(1.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Comma-separated `DateTime.weekday` values (1=Monday..7=Sunday), or
  /// empty for a one-shot alarm. Text rather than a bitmask so the raw
  /// column is readable in a DB browser (plan discussion: "days-of-week"
  /// recurrence).
  TextColumn get recurringDays => text().withDefault(const Constant(''))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
