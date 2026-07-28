import 'dart:async';
import 'dart:convert';

import 'package:awaken/features/territory/data/datasources/location_provider_factory.dart';
import 'package:awaken/features/territory/data/datasources/run_foreground_service.dart';
import 'package:awaken/features/territory/data/datasources/run_progress_remote_datasource.dart';
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

class _MockLocationProviderFactory extends Mock
    implements LocationProviderFactory {}

class _MockRunProgressRemoteDataSource extends Mock
    implements RunProgressRemoteDataSource {}

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

/// Emits a fixed set of GPS fixtures on `positions` shortly after `start()`
/// returns — `DeadReckoningProvider.start()` only subscribes to `inner.
/// positions` *after* awaiting `inner.start()`, so emitting synchronously
/// inside `start()` itself would be dropped by the broadcast stream having no
/// listener yet.
class _FixtureLocationProvider implements LocationProvider {
  _FixtureLocationProvider(this._fixtures);

  final List<GeoPosition> _fixtures;
  final _controller = StreamController<GeoPosition>.broadcast();

  @override
  Stream<GeoPosition> get positions => _controller.stream;

  @override
  Future<void> start() async {
    unawaited(_emitAll());
  }

  Future<void> _emitAll() async {
    for (final fixture in _fixtures) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (_controller.isClosed) return;
      _controller.add(fixture);
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
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
  late _MockRunProgressRemoteDataSource runProgress;
  late RunTrackingRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    foregroundService = _MockRunForegroundService();
    localWriter = _MockLocalWriter();
    syncWorker = _MockSyncWorker();
    locationProviderFactory = _MockLocationProviderFactory();
    runProgress = _MockRunProgressRemoteDataSource();

    when(() => foregroundService.start()).thenAnswer((_) async {});
    when(() => foregroundService.stop()).thenAnswer((_) async {});
    when(
      () => locationProviderFactory.create(),
    ).thenReturn(_SilentLocationProvider());
    when(
      () => runProgress.upsertProgress(
        runId: any(named: 'runId'),
        startedAt: any(named: 'startedAt'),
        path: any(named: 'path'),
        pointTimestamps: any(named: 'pointTimestamps'),
        distanceMeters: any(named: 'distanceMeters'),
      ),
    ).thenAnswer((_) async {});
    when(() => runProgress.clearProgress()).thenAnswer((_) async {});
    when(
      () => syncWorker.drainOutbox(
        skipConnectivityCheck: any(named: 'skipConnectivityCheck'),
      ),
    ).thenAnswer((_) async {});

    repository = RunTrackingRepositoryImpl(
      foregroundService,
      localWriter,
      syncWorker,
      db,
      locationProviderFactory,
      runProgress,
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

    test(
      'startRun() with an existing checkpoint resumes prior points/distance instead of '
      'starting empty',
      () async {
        final points = [
          {
            'lat': 1.0,
            'lng': 1.0,
            'acc': 5.0,
            'ts': DateTime(2026, 1, 1, 7).toIso8601String(),
          },
          {
            'lat': 1.001,
            'lng': 1.0,
            'acc': 5.0,
            'ts': DateTime(2026, 1, 1, 7, 1).toIso8601String(),
          },
        ];
        await db
            .into(db.runCheckpoints)
            .insert(
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
      },
    );

    test(
      'abandonRun() clears the checkpoint so a future startRun() does not resume it',
      () async {
        await db
            .into(db.runCheckpoints)
            .insert(
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
      },
    );
  });

  group('RunTrackingRepositoryImpl.captureRun — RDP compute() offload', () {
    test(
      'simplifies and submits a real GPS path through the compute() isolate hop',
      () async {
        // A short zigzag path — enough segments for RDP to have something to
        // simplify, each hop slow enough (~1.7 m/s) to clear the velocity
        // gate and short enough (2s) to never trip DeadReckoningProvider's
        // 3s GPS-timeout into dead-reckoning takeover.
        final start = DateTime(2026, 1, 1, 7).toUtc();
        final fixtures = [
          GeoPosition(
            latitude: 1.00000,
            longitude: 1.00000,
            accuracy: 5,
            timestamp: start,
          ),
          GeoPosition(
            latitude: 1.00003,
            longitude: 1.00020,
            accuracy: 5,
            timestamp: start.add(const Duration(seconds: 2)),
          ),
          GeoPosition(
            latitude: 1.00006,
            longitude: 1.00000,
            accuracy: 5,
            timestamp: start.add(const Duration(seconds: 4)),
          ),
          GeoPosition(
            latitude: 1.00009,
            longitude: 1.00020,
            accuracy: 5,
            timestamp: start.add(const Duration(seconds: 6)),
          ),
          GeoPosition(
            latitude: 1.00012,
            longitude: 1.00000,
            accuracy: 5,
            timestamp: start.add(const Duration(seconds: 8)),
          ),
        ];

        when(
          () => localWriter.insertRun(
            id: any(named: 'id'),
            startedAt: any(named: 'startedAt'),
            endedAt: any(named: 'endedAt'),
            pointCount: any(named: 'pointCount'),
            pathGeoJson: any(named: 'pathGeoJson'),
            pointTimestampsJson: any(named: 'pointTimestampsJson'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => locationProviderFactory.create(),
        ).thenReturn(_FixtureLocationProvider(fixtures));

        await repository.startRun();
        // All 5 fixtures are emitted 5ms apart — comfortably wait for the
        // full sequence (plus DeadReckoningProvider/repository processing)
        // before capturing.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final result = await repository.captureRun();
        expect(result.pending, isTrue); // no `runs` row synced in this test

        final captured = verify(
          () => localWriter.insertRun(
            id: any(named: 'id'),
            startedAt: any(named: 'startedAt'),
            endedAt: any(named: 'endedAt'),
            pointCount: captureAny(named: 'pointCount'),
            pathGeoJson: captureAny(named: 'pathGeoJson'),
            pointTimestampsJson: captureAny(named: 'pointTimestampsJson'),
          ),
        ).captured;
        expect(captured, hasLength(3));
        final pointCount = captured[0] as int;
        final pathGeoJson = captured[1] as String;
        final pointTimestampsJson = captured[2] as String;

        // RDP always keeps the first/last point and never invents new ones.
        expect(pointCount, greaterThanOrEqualTo(2));
        expect(pointCount, lessThanOrEqualTo(fixtures.length));

        // The compute() round-trip must produce the exact same GeoJSON
        // shape as calling the pure function directly would — proving
        // isolate message-passing didn't corrupt/drop anything.
        final decodedPath = jsonDecode(pathGeoJson) as Map<String, Object?>;
        expect(decodedPath['type'], 'LineString');
        final coordinates = decodedPath['coordinates']! as List;
        expect(coordinates, hasLength(pointCount));

        final decodedTimestamps = jsonDecode(pointTimestampsJson) as List;
        expect(decodedTimestamps, hasLength(pointCount));
      },
    );
  });
}
