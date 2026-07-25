import 'dart:convert';

import 'package:awaken/features/territory/data/datasources/location_provider_factory.dart';
import 'package:awaken/features/territory/data/datasources/run_foreground_service.dart';
import 'package:awaken/features/territory/data/repositories/run_tracking_repository_impl.dart';
import 'package:awaken/sync/local/database.dart';
import 'package:awaken/sync/outbox/local_writer.dart';
import 'package:awaken/sync/outbox/sync_worker.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalman_dr/kalman_dr.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// `WakelockPlus.enable/disable` normally goes over a platform channel,
/// which has nothing to answer it in a plain `flutter test` — swap in a
/// no-op fake via the package's own `@visibleForTesting` hook rather than
/// mocking the raw pigeon channel.
class _FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
}

class _MockRunForegroundService extends Mock implements RunForegroundService {}

class _MockLocalWriter extends Mock implements LocalWriter {}

class _MockSyncWorker extends Mock implements SyncWorker {}

class _MockLocationProviderFactory extends Mock implements LocationProviderFactory {}

/// Never emits a position — this test only exercises the resume-from-
/// checkpoint path (does startRun() correctly restore prior state?), not
/// live GPS accumulation.
class _SilentLocationProvider implements LocationProvider {
  @override
  Stream<GeoPosition> get positions => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() {
    wakelockPlusPlatformInstance = _FakeWakelockPlusPlatform();
  });

  late AppDatabase db;
  late _MockRunForegroundService foregroundService;
  late _MockLocalWriter localWriter;
  late _MockSyncWorker syncWorker;
  late _MockLocationProviderFactory locationProviderFactory;
  late RunTrackingRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    foregroundService = _MockRunForegroundService();
    localWriter = _MockLocalWriter();
    syncWorker = _MockSyncWorker();
    locationProviderFactory = _MockLocationProviderFactory();

    when(() => foregroundService.start()).thenAnswer((_) async {});
    when(() => foregroundService.stop()).thenAnswer((_) async {});
    when(() => locationProviderFactory.create()).thenReturn(_SilentLocationProvider());

    repository = RunTrackingRepositoryImpl(
      foregroundService,
      localWriter,
      syncWorker,
      db,
      locationProviderFactory,
    );
  });

  tearDown(() => db.close());

  group('RunTrackingRepositoryImpl — checkpoint resume (resilience fix)', () {
    test('startRun() with no checkpoint begins a fresh, empty run', () async {
      await repository.startRun();
      final state = await repository.watchRunState().first;

      expect(state.isTracking, isTrue);
      expect(state.points, isEmpty);
      expect(state.distanceMeters, 0);
    });

    test('startRun() with an existing checkpoint resumes prior points/distance instead of '
        'starting empty', () async {
      final points = [
        {'lat': 1.0, 'lng': 1.0, 'acc': 5.0, 'ts': DateTime(2026, 1, 1, 7).toIso8601String()},
        {'lat': 1.001, 'lng': 1.0, 'acc': 5.0, 'ts': DateTime(2026, 1, 1, 7, 1).toIso8601String()},
      ];
      await db.into(db.runCheckpoints).insert(
            RunCheckpointsCompanion.insert(
              runId: 'interrupted-run-id',
              startedAt: DateTime(2026, 1, 1, 7),
              pointsJson: jsonEncode(points),
              distanceMeters: 123.4,
              updatedAt: DateTime(2026, 1, 1, 7, 1),
            ),
          );

      await repository.startRun();
      final state = await repository.watchRunState().first;

      expect(state.isTracking, isTrue);
      expect(state.points, hasLength(2));
      expect(state.points.first.latitude, 1.0);
      expect(state.distanceMeters, 123.4);
    });

    test('abandonRun() clears the checkpoint so a future startRun() does not resume it', () async {
      await db.into(db.runCheckpoints).insert(
            RunCheckpointsCompanion.insert(
              runId: 'stale-run-id',
              startedAt: DateTime(2026, 1, 1, 7),
              pointsJson: jsonEncode(<Object?>[]),
              distanceMeters: 0,
              updatedAt: DateTime(2026, 1, 1, 7),
            ),
          );

      await repository.startRun();
      await repository.abandonRun();

      final remaining = await db.select(db.runCheckpoints).get();
      expect(remaining, isEmpty);
    });
  });
}
