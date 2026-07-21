import 'package:awaken/sync/local/database.dart';
import 'package:awaken/sync/outbox/local_writer.dart';
import 'package:awaken/sync/outbox/outbox_operation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §8: "outbox invariants (property-based: every local write ⇒ outbox
/// row in same txn)". Runs against a real in-memory sqlite3 instance (not a
/// mock) so the transaction actually has to hold for these to pass.
void main() {
  late AppDatabase db;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(db);
  });

  tearDown(() => db.close());

  group('LocalWriter outbox invariant', () {
    test('upsertAlarm writes the alarm row and enqueues exactly one outbox entry', () async {
      await writer.upsertAlarm(
        id: 'alarm-1',
        scheduledTime: DateTime(2026, 7, 19, 7),
        exerciseMode: 'squat',
        requiredReps: 20,
        penaltyMultiplier: 1.0,
        isActive: true,
      );

      final alarms = await db.select(db.alarms).get();
      final outbox = await db.select(db.syncOutbox).get();

      expect(alarms, hasLength(1));
      expect(alarms.single.id, 'alarm-1');
      expect(outbox, hasLength(1));
      expect(outbox.single.entityTable, 'alarms');
      expect(outbox.single.entityId, 'alarm-1');
      expect(outbox.single.operation, OutboxOperation.upsert.name);
    });

    test('deleteAlarm soft-deletes and enqueues a delete entry', () async {
      await writer.upsertAlarm(
        id: 'alarm-2',
        scheduledTime: DateTime(2026, 7, 19, 7),
        exerciseMode: 'pushup',
        requiredReps: 15,
        penaltyMultiplier: 1.5,
        isActive: true,
      );

      await writer.deleteAlarm('alarm-2');

      final alarm = await (db.select(db.alarms)..where((t) => t.id.equals('alarm-2'))).getSingle();
      final outbox = await db.select(db.syncOutbox).get();

      expect(alarm.deletedAt, isNotNull);
      expect(alarm.isActive, isFalse);
      expect(outbox, hasLength(2)); // original upsert + delete
      expect(outbox.last.operation, OutboxOperation.delete.name);
    });

    test('insertSession and insertRun each enqueue an outbox row', () async {
      await writer.insertSession(
        id: 'session-1',
        exerciseMode: 'squat',
        repsCompleted: 20,
        startedAt: DateTime(2026, 7, 19, 7),
        completedAt: DateTime(2026, 7, 19, 7, 5),
      );
      await writer.insertRun(
        id: 'run-1',
        startedAt: DateTime(2026, 7, 19, 8),
        pointCount: 120,
        pathGeoJson: '{"type":"LineString","coordinates":[]}',
      );

      final outbox = await db.select(db.syncOutbox).get();
      final tables = outbox.map((e) => e.entityTable).toSet();

      expect(outbox, hasLength(2));
      expect(tables, {'sessions', 'runs'});
    });

    test('upsertUserStats writes the singleton row and enqueues an outbox entry', () async {
      await writer.upsertUserStats(currentTaxMultiplier: 1.5);

      final stats = await db.select(db.userStats).get();
      final outbox = await db.select(db.syncOutbox).get();

      expect(stats, hasLength(1));
      expect(stats.single.currentTaxMultiplier, 1.5);
      expect(outbox.single.entityTable, 'user_stats');
      expect(outbox.single.operation, OutboxOperation.upsert.name);
    });

    test('a failed write leaves no orphaned outbox row (transactional rollback)', () async {
      // Re-using the same id twice with insertSession (which does a plain
      // `insert`, not upsert) violates the primary key on the second call —
      // the whole transaction, including the outbox enqueue, must roll back.
      await writer.insertSession(
        id: 'dup',
        exerciseMode: 'squat',
        repsCompleted: 5,
        startedAt: DateTime(2026, 7, 19),
      );

      await expectLater(
        writer.insertSession(
          id: 'dup',
          exerciseMode: 'squat',
          repsCompleted: 5,
          startedAt: DateTime(2026, 7, 19),
        ),
        throwsA(anything),
      );

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(1)); // only the first, successful insert
    });
  });
}
