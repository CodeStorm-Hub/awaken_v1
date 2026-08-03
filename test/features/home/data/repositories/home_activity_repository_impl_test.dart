import 'package:awaken/features/home/data/repositories/home_activity_repository_impl.dart';
import 'package:awaken/features/home/domain/entities/recent_activity_entry.dart';
import 'package:awaken/sync/local/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late HomeActivityRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = HomeActivityRepositoryImpl(db);
  });

  tearDown(() => db.close());

  Future<void> insertSession({
    required String id,
    required DateTime completedAt,
    String exerciseMode = 'squat',
    int reps = 10,
  }) {
    return db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: id,
            exerciseMode: exerciseMode,
            repsCompleted: reps,
            startedAt: completedAt,
            completedAt: Value(completedAt),
            updatedAt: completedAt,
          ),
        );
  }

  Future<void> insertRun({
    required String id,
    required DateTime endedAt,
    required double capturedAreaSqm,
  }) {
    return db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            id: id,
            startedAt: endedAt,
            endedAt: Value(endedAt),
            pointCount: 10,
            pathGeoJson: '{}',
            capturedAreaSqm: Value(capturedAreaSqm),
            updatedAt: endedAt,
          ),
        );
  }

  test(
    'merges sessions and runs into one feed sorted most-recent-first',
    () async {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 1, 2);
      final t3 = DateTime(2026, 1, 3);

      await insertSession(id: 's1', completedAt: t1);
      await insertRun(id: 'r1', endedAt: t3, capturedAreaSqm: 500);
      await insertSession(id: 's2', completedAt: t2);

      final result = await repository.watchRecentActivity(limit: 10).first;

      expect(result.map((e) => e.occurredAt), [t3, t2, t1]);
      expect(result[0].kind, RecentActivityKind.territoryCaptured);
      expect(result[1].kind, RecentActivityKind.alarmDismissed);
    },
  );

  test('respects the limit across both sources combined', () async {
    final base = DateTime(2026, 1, 1);
    for (var i = 0; i < 5; i++) {
      await insertSession(id: 's$i', completedAt: base.add(Duration(days: i)));
    }
    for (var i = 0; i < 5; i++) {
      await insertRun(
        id: 'r$i',
        endedAt: base.add(Duration(days: i, hours: 12)),
        capturedAreaSqm: 100,
      );
    }

    final result = await repository.watchRecentActivity(limit: 3).first;

    expect(result, hasLength(3));
  });

  test(
    'excludes soft-deleted rows and incomplete sessions/runs',
    () async {
      final t = DateTime(2026, 1, 1);
      await insertSession(id: 'complete', completedAt: t);
      // No completedAt — an in-progress/skipped session, must not appear.
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              id: 'incomplete',
              exerciseMode: 'squat',
              repsCompleted: 0,
              startedAt: t,
              updatedAt: t,
            ),
          );
      await insertRun(id: 'run1', endedAt: t, capturedAreaSqm: 200);
      // Soft-deleted run must not appear even though endedAt is set.
      await db
          .into(db.runs)
          .insert(
            RunsCompanion.insert(
              id: 'deleted-run',
              startedAt: t,
              endedAt: Value(t),
              pointCount: 5,
              pathGeoJson: '{}',
              capturedAreaSqm: const Value(999),
              updatedAt: t,
              deletedAt: Value(t),
            ),
          );

      final result = await repository.watchRecentActivity(limit: 10).first;

      expect(result, hasLength(2));
      expect(result.any((e) => e.text.contains('999')), isFalse);
    },
  );

  test('waits for both sources before emitting, even if one is empty', () async {
    // Only a run, no sessions at all — must still emit (not hang forever
    // waiting for a sessions row that will never come).
    await insertRun(id: 'r1', endedAt: DateTime(2026, 1, 1), capturedAreaSqm: 42);

    final result = await repository.watchRecentActivity(limit: 10).first;

    expect(result, hasLength(1));
    expect(result.single.kind, RecentActivityKind.territoryCaptured);
  });
}
