import 'package:drift/drift.dart';

/// Single-row (id always 1) snapshot of the currently in-progress run, if
/// any. Written periodically (~10s) by `RunTrackingRepositoryImpl` while
/// tracking is active — refined territory plan's resilience requirement:
/// a run must survive the OS killing the app process, bounded by this
/// checkpoint interval, without needing GPS collection to run in a
/// separate background isolate. Cleared on normal completion (capture or
/// abandon); read once at the next `startRun()` call to offer/perform
/// automatic resume instead of silently losing the in-progress path.
@DataClassName('RunCheckpointRow')
class RunCheckpoints extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get runId => text()();
  DateTimeColumn get startedAt => dateTime()();

  /// JSON-encoded `List<TrackPoint>` — see `TrackPoint.toJson`.
  TextColumn get pointsJson => text()();
  RealColumn get distanceMeters => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
