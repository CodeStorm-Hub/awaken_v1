import 'package:awaken/sync/local/database.dart';
import 'package:awaken/sync/outbox/local_writer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the account-transition data-wipe behavior
/// (`AuthRepositoryImpl._clearIdentityState` calls `AppDatabase
/// .clearAllLocalData()` on sign-in/sign-out/delete so User A's offline
/// writes never leak into User B's session on the same device) — this was
/// implemented but never locked in by a test (session hardening-pass
/// item #17). Exercises `clearAllLocalData()` directly against a real
/// in-memory sqlite3 instance rather than mocking `AuthRepositoryImpl`'s
/// full dependency graph (alarm/squad repos, remote datasource) — the
/// property that actually matters here is "every locally-cached table is
/// empty after the wipe", which doesn't need any of that.
void main() {
  late AppDatabase db;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(db);
  });

  tearDown(() => db.close());

  test(
    'clearAllLocalData wipes every locally-cached table, simulating '
    "User A's offline writes not surviving into User B's session",
    () async {
      // Seed every table `clearAllLocalData` is documented to cover, as if
      // User A had been using the app offline: an alarm, a completed
      // session, a captured run, a synced-down territory, user stats, an
      // in-progress run checkpoint, and a pull watermark.
      await writer.upsertAlarm(
        id: 'alarm-a',
        nativeId: 1,
        scheduledTime: DateTime(2026, 7, 19, 7),
        exerciseMode: 'squat',
        requiredReps: 20,
        penaltyMultiplier: 1.0,
        isActive: true,
      );
      await writer.insertSession(
        id: 'session-a',
        exerciseMode: 'squat',
        repsCompleted: 20,
        startedAt: DateTime(2026, 7, 19, 7),
        completedAt: DateTime(2026, 7, 19, 7, 5),
      );
      await writer.insertRun(
        id: 'run-a',
        startedAt: DateTime(2026, 7, 19, 8),
        pointCount: 3,
        pathGeoJson: '{"type":"LineString","coordinates":[]}',
      );
      await writer.upsertUserStats(currentTaxMultiplier: 2.0, action: 'bump');

      await db
          .into(db.territories)
          .insert(
            TerritoriesCompanion.insert(
              id: 'territory-a',
              ownerId: 'user-a',
              geoJson: '{"type":"MultiPolygon","coordinates":[]}',
              areaSqm: 500.0,
              updatedAt: DateTime(2026, 7, 19),
            ),
          );
      await db
          .into(db.runCheckpoints)
          .insert(
            RunCheckpointsCompanion.insert(
              runId: 'run-a',
              startedAt: DateTime(2026, 7, 19, 9),
              pointsJson: '[]',
              distanceMeters: 120.0,
              updatedAt: DateTime(2026, 7, 19, 9),
            ),
          );
      await db
          .into(db.syncMeta)
          .insert(
            SyncMetaCompanion.insert(
              entityTable: 'alarms',
              lastPulledAt: DateTime(2026, 7, 19),
            ),
          );

      // Sanity-check the seed actually landed before wiping — a test that
      // passes because nothing was ever inserted would be worthless.
      expect(await db.select(db.alarms).get(), isNotEmpty);
      expect(await db.select(db.sessions).get(), isNotEmpty);
      expect(await db.select(db.runs).get(), isNotEmpty);
      expect(await db.select(db.territories).get(), isNotEmpty);
      expect(await db.select(db.userStats).get(), isNotEmpty);
      expect(await db.select(db.runCheckpoints).get(), isNotEmpty);
      expect(await db.select(db.syncMeta).get(), isNotEmpty);
      expect(await db.select(db.syncOutbox).get(), isNotEmpty);

      await db.clearAllLocalData();

      expect(await db.select(db.alarms).get(), isEmpty);
      expect(await db.select(db.sessions).get(), isEmpty);
      expect(await db.select(db.runs).get(), isEmpty);
      expect(await db.select(db.territories).get(), isEmpty);
      expect(await db.select(db.userStats).get(), isEmpty);
      expect(await db.select(db.runCheckpoints).get(), isEmpty);
      expect(await db.select(db.syncMeta).get(), isEmpty);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    },
  );

  test('clearAllLocalData is idempotent on an already-empty database', () async {
    // Signing out with no local data yet (e.g. a fresh install) must not
    // throw — every `delete(...).go()` call is a no-op on an empty table.
    await db.clearAllLocalData();
    expect(await db.select(db.alarms).get(), isEmpty);
  });
}
