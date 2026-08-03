import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:injectable/injectable.dart';

import '../../../../sync/local/database.dart';
import '../../domain/entities/recent_activity_entry.dart';
import '../../domain/repositories/home_activity_repository.dart';

/// Read-only, like `TerritoryRepositoryImpl` reading straight from
/// `AppDatabase` — this is a cross-feature view over `sessions` (alarm)
/// and `runs` (territory), not something either feature owns on its own.
/// Replaces the Home page's previous hardcoded mock activity list.
@LazySingleton(as: HomeActivityRepository)
class HomeActivityRepositoryImpl implements HomeActivityRepository {
  HomeActivityRepositoryImpl(this._db);

  final AppDatabase _db;

  String _exerciseLabel(String mode) => mode == 'squat' ? 'squats' : 'push-ups';

  @override
  Stream<List<RecentActivityEntry>> watchRecentActivity({int limit = 3}) {
    late final StreamController<List<RecentActivityEntry>> controller;
    List<RecentActivityEntry> latestSessions = const [];
    List<RecentActivityEntry> latestRuns = const [];
    var hasSessions = false;
    var hasRuns = false;

    void emitIfReady() {
      if (!hasSessions || !hasRuns) return;
      final merged = [...latestSessions, ...latestRuns]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      controller.add(merged.take(limit).toList());
    }

    late final StreamSubscription<List<SessionRow>> sessionsSub;
    late final StreamSubscription<List<RunRow>> runsSub;

    controller = StreamController<List<RecentActivityEntry>>.broadcast(
      onListen: () {
        final sessionsQuery = _db.select(_db.sessions)
          ..where((t) => t.completedAt.isNotNull())
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
          ..limit(limit);
        sessionsSub = sessionsQuery.watch().listen((rows) {
          latestSessions = rows.map((row) {
            return RecentActivityEntry(
              kind: RecentActivityKind.alarmDismissed,
              text:
                  'Dismissed alarm — ${row.repsCompleted} ${_exerciseLabel(row.exerciseMode)}',
              occurredAt: row.completedAt!,
            );
          }).toList();
          hasSessions = true;
          emitIfReady();
        });

        final runsQuery = _db.select(_db.runs)
          ..where((t) => t.capturedAreaSqm.isNotNull())
          ..where((t) => t.endedAt.isNotNull())
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.endedAt)])
          ..limit(limit);
        runsSub = runsQuery.watch().listen((rows) {
          latestRuns = rows.map((row) {
            final km2 = row.capturedAreaSqm! / 1000000;
            return RecentActivityEntry(
              kind: RecentActivityKind.territoryCaptured,
              text: 'Captured ${km2.toStringAsFixed(2)} km² of territory',
              occurredAt: row.endedAt!,
            );
          }).toList();
          hasRuns = true;
          emitIfReady();
        });
      },
      onCancel: () {
        unawaited(sessionsSub.cancel());
        unawaited(runsSub.cancel());
      },
    );

    return controller.stream;
  }
}
