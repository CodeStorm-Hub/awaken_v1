import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:injectable/injectable.dart';
import 'package:kalman_dr/kalman_dr.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../sync/local/database.dart';
import '../../../../sync/outbox/local_writer.dart';
import '../../../../sync/outbox/sync_worker.dart';
import '../../domain/entities/gps_quality.dart';
import '../../domain/entities/run_capture_result.dart';
import '../../domain/entities/run_track_state.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/repositories/run_tracking_repository.dart';
import '../datasources/location_provider_factory.dart';
import '../datasources/run_foreground_service.dart';
import '../datasources/run_progress_remote_datasource.dart';
import '../mappers/path_simplifier.dart';

@LazySingleton(as: RunTrackingRepository)
class RunTrackingRepositoryImpl implements RunTrackingRepository {
  RunTrackingRepositoryImpl(
    this._foregroundService,
    this._localWriter,
    this._syncWorker,
    this._db,
    this._locationProviderFactory,
    this._runProgress,
  );

  final RunForegroundService _foregroundService;
  final LocalWriter _localWriter;
  final SyncWorker _syncWorker;
  final AppDatabase _db;
  final RunProgressRemoteDataSource _runProgress;

  /// Real GPS in production, a fixture-replaying provider in `main_e2e.dart`
  /// builds — see `RegisterModule.locationProviderFactory`.
  final LocationProviderFactory _locationProviderFactory;

  final _stateController = StreamController<RunTrackState>.broadcast();
  RunTrackState _state = const RunTrackState();

  DeadReckoningProvider? _locationProvider;
  StreamSubscription<GeoPosition>? _positionSub;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _runId;
  DateTime? _lastCheckpointAt;

  /// Minimum gap between checkpoint writes — refined territory plan's
  /// resilience requirement: bound data loss to roughly this interval if
  /// the OS kills the app process mid-run, without needing GPS collection
  /// to run in a separate background isolate (see plan doc "Territory
  /// feature v2" §Resilience for why the lighter checkpoint approach was
  /// chosen over full isolate-bridging).
  static const _checkpointInterval = Duration(seconds: 10);

  @override
  Stream<RunTrackState> watchRunState() async* {
    yield _state;
    yield* _stateController.stream;
  }

  void _emit(RunTrackState next) {
    _state = next;
    _stateController.add(_state);
  }

  @override
  Future<void> startRun() async {
    // Must read any existing checkpoint *before* teardown/reset — this is
    // the only moment a prior session's orphaned checkpoint (app was
    // killed mid-run) can be detected.
    final checkpoint = await (_db.select(
      _db.runCheckpoints,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    await _teardown();

    if (checkpoint != null) {
      final points = (jsonDecode(checkpoint.pointsJson) as List)
          .map((e) => TrackPoint.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      await _beginTracking(
        runId: checkpoint.runId,
        startedAt: checkpoint.startedAt,
        initialPoints: points,
        initialDistance: checkpoint.distanceMeters,
      );
      return;
    }

    await _beginTracking(
      runId: const Uuid().v4(),
      // UTC, not local — this value flows into `submit_run()`'s
      // `p_started_at` (via `LocalWriter.insertRun`), which is compared
      // against GPS-fix timestamps (already UTC) with only a 5-minute
      // tolerance. See `LocalWriter.insertRun`'s doc comment.
      startedAt: DateTime.now().toUtc(),
      initialPoints: const [],
      initialDistance: 0,
    );
  }

  /// Shared by a fresh `startRun()` and an automatic resume from a
  /// checkpoint — everything past "what points/distance/id do we start
  /// from" is identical either way.
  Future<void> _beginTracking({
    required String runId,
    required DateTime startedAt,
    required List<TrackPoint> initialPoints,
    required double initialDistance,
  }) async {
    _runId = runId;
    _startedAt = startedAt;
    _emit(
      RunTrackState(
        isTracking: true,
        points: initialPoints,
        distanceMeters: initialDistance,
        elapsed: DateTime.now().difference(startedAt),
      ),
    );

    final provider = DeadReckoningProvider(
      inner: _locationProviderFactory.create(),
      mode: DeadReckoningMode.kalman,
    );
    _locationProvider = provider;

    // Permission must be confirmed *before* starting the foreground service
    // — Android 14+ can reject a location-type foreground service outright
    // if runtime location permission isn't already granted, and starting
    // the service (and its persistent notification) first left a stray
    // "tracking" notification up with no permission and no actual tracking
    // on denial.
    try {
      await provider.start();
    } on LocationPermissionDeniedException {
      _emit(_state.copyWith(isTracking: false, permissionDenied: true));
      await _teardown();
      return;
    }

    // Comprehensive start-failure cleanup: previously only the permission
    // exception above was caught, so any other failure here (foreground
    // service start, wakelock) propagated uncaught with `isTracking: true`
    // already emitted and no teardown — leaking a running service/wakelock
    // and leaving the UI stuck believing a run is active.
    try {
      await _foregroundService.start();
      await WakelockPlus.enable();
    } catch (_) {
      _emit(_state.copyWith(isTracking: false, startFailed: true));
      await _teardown();
      return;
    }

    _positionSub = provider.positions.listen(
      _onPosition,
      onError: _onPositionError,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _startedAt;
      if (started == null) return;
      _emit(_state.copyWith(elapsed: DateTime.now().difference(started)));
    });
  }

  void _onPosition(GeoPosition position) {
    // Real bug found via live device/emulator testing: `kalman_dr`'s
    // `DeadReckoningProvider` transparently keeps emitting *extrapolated*
    // positions on the same `positions` stream once real GPS has been lost
    // for `gpsTimeout` (3s) — without this check, those synthetic
    // "phantom movement" fixes were being accumulated into `distanceMeters`
    // and `points` exactly like real GPS, letting a run's distance grow (and
    // even close a loop) with zero actual movement, e.g. walking into a
    // tunnel/underpass. Territory capture must only reward verified real
    // movement, so extrapolated fixes are dropped from the tracked path
    // entirely — surfaced to the user as degraded GPS quality instead.
    if (_locationProvider?.isDrActive ?? false) {
      _emit(_state.copyWith(gpsQuality: GpsQuality.poor));
      return;
    }

    final quality = GpsQuality.fromAccuracyMeters(position.accuracy);
    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );

    final points = _state.points;
    if (points.isEmpty) {
      _emit(_state.copyWith(points: [point], gpsQuality: quality));
      unawaited(_maybeWriteCheckpoint());
      return;
    }

    final previous = points.last;
    final segmentMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );
    final segmentSeconds =
        point.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;

    // Client-side velocity gate (plan H7): a physically-impossible implied
    // speed between consecutive fixes is dropped rather than accepted into
    // the path — cheap pre-filter only, server-side `submit_run()` stays
    // authoritative for anti-cheat.
    //
    // Real bug found via live device/emulator testing: the original
    // `segmentSeconds > 0 && speed > cap` condition let a fix straight
    // through, unlimited distance included, whenever segmentSeconds was
    // zero or negative (two consecutive smoothed fixes reporting the same
    // or an out-of-order timestamp — reproduced live with the Android
    // emulator's `emu geo fix`: a single clean 30m step registered as an
    // ~8,900km jump). A non-positive time delta means the implied speed is
    // undefined/unverifiable, not "automatically fine" — must drop the fix
    // in that case too, not just when the computed speed is too high.
    if (segmentSeconds <= 0 ||
        segmentMeters / segmentSeconds >
            AppConstants.maxSustainedSpeedMetersPerSecond) {
      _emit(_state.copyWith(gpsQuality: quality));
      return;
    }

    _emit(
      _state.copyWith(
        points: [...points, point],
        distanceMeters: _state.distanceMeters + segmentMeters,
        gpsQuality: quality,
      ),
    );
    unawaited(_maybeWriteCheckpoint());
  }

  void _onPositionError(Object error) {
    // `DeadReckoningAccuracyExceededException` signals GPS loss exceeding
    // the safety cap (kalman_dr's terminal "position unavailable" signal) —
    // surface it as a quality drop, not a crash; tracking keeps running so
    // the moment GPS returns, `_onPosition` resumes normally.
    _emit(_state.copyWith(gpsQuality: GpsQuality.poor));
  }

  /// Throttled disk checkpoint — refined territory plan's resilience
  /// requirement. Best-effort: a write failure here must never interrupt
  /// live tracking, so errors are swallowed rather than surfaced.
  ///
  /// Also mirrors the same snapshot to the `active_runs` Supabase table
  /// (real-time backup, distinct from the local-only checkpoint above) —
  /// so an in-progress run survives worse than an app-process kill (device
  /// loss, uninstall, local DB corruption) instead of existing only on this
  /// one device until the final `submit_run()` call succeeds. Same
  /// best-effort policy: a failed push (offline, etc.) is silently retried
  /// on the next tick, never surfaced to the tracking UI.
  Future<void> _maybeWriteCheckpoint() async {
    final runId = _runId;
    final startedAt = _startedAt;
    if (runId == null || startedAt == null) return;
    final now = DateTime.now();
    final last = _lastCheckpointAt;
    if (last != null && now.difference(last) < _checkpointInterval) return;
    _lastCheckpointAt = now;
    final points = _state.points;
    try {
      await _db
          .into(_db.runCheckpoints)
          .insertOnConflictUpdate(
            RunCheckpointsCompanion.insert(
              id: const Value(1),
              runId: runId,
              startedAt: startedAt,
              pointsJson: jsonEncode(
                points.map((p) => p.toJson()).toList(),
              ),
              distanceMeters: _state.distanceMeters,
              updatedAt: now,
            ),
          );
    } catch (_) {
      // Best-effort — see doc comment above.
    }
    if (points.length < 2) return;
    try {
      await _runProgress.upsertProgress(
        runId: runId,
        startedAt: startedAt,
        path: PathSimplifier.toGeoJsonMap(points),
        pointTimestamps: [
          for (final p in points) p.timestamp.toUtc().toIso8601String(),
        ],
        distanceMeters: _state.distanceMeters,
      );
    } catch (_) {
      // Best-effort — see doc comment above.
    }
  }

  Future<void> _clearCheckpoint() async {
    await (_db.delete(_db.runCheckpoints)..where((t) => t.id.equals(1))).go();
    try {
      await _runProgress.clearProgress();
    } catch (_) {
      // Best-effort — a leftover row is harmless (overwritten by the next
      // run's first checkpoint) and must never block finishing this one.
    }
  }

  @override
  Future<void> abandonRun() async {
    await _teardown();
    await _clearCheckpoint();
    _emit(const RunTrackState());
  }

  @override
  Future<RunCaptureResult> captureRun() async {
    final points = _state.points;
    final startedAt = _startedAt;
    // Falls back to a fresh id only in the defensive case where capture is
    // somehow called with no active run (_runId null) — should not happen
    // in practice since captureRun() is only reachable from an active
    // tracking session.
    final id = _runId ?? const Uuid().v4();
    await _teardown();
    await _clearCheckpoint();

    if (points.length < 2 || startedAt == null) {
      _emit(const RunTrackState());
      return const RunCaptureResult(
        pending: false,
        accepted: false,
        rejectedReason: 'No GPS points captured',
      );
    }

    final simplified = PathSimplifier.simplify(points);
    final endedAt = points.last.timestamp;

    await _localWriter.insertRun(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      pointCount: simplified.length,
      pathGeoJson: PathSimplifier.toGeoJsonLineString(simplified),
      pointTimestampsJson: PathSimplifier.toTimestampsJson(simplified),
    );

    // Best-effort immediate push (plan §3 — "return the delta for
    // client-side celebration UI"): if online, `SyncWorker`'s `runs`
    // special-case (`_pushRun`) calls `submit_run()` synchronously here and
    // updates the local row before this returns. If offline, the row stays
    // queued in the outbox and this just falls through to the pending case.
    //
    // `skipConnectivityCheck: true` — real bug found live: `connectivity_
    // plus`'s local network-interface check can report a stale/false
    // "offline" right after a transition, which made this fall through to
    // the pending case even while genuinely online (a captured territory
    // silently never appeared, only "will sync once back online"). This is
    // the one call site where that matters — the user is actively watching
    // right now, so it's always worth actually trying the real network
    // call instead of trusting the local heuristic first. A genuinely
    // offline attempt still fails fast and falls back to the normal
    // backoff/retry path.
    await _syncWorker.drainOutbox(skipConnectivityCheck: true);

    final row = await (_db.select(
      _db.runs,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    _emit(const RunTrackState());

    if (row == null || row.integrityVerdict == null) {
      return const RunCaptureResult.pending();
    }
    return RunCaptureResult(
      pending: false,
      accepted: row.integrityVerdict == 'trusted',
      closedLoop: row.isClosedLoop,
      capturedAreaSqm: row.capturedAreaSqm,
      territoryAreaSqm: row.areaSqm,
      bonusAreaSqm: row.bonusAreaSqm,
      bountyMultiplier: row.bountyMultiplier,
      rejectedReason: row.rejectedReason,
    );
  }

  @override
  Future<({double latitude, double longitude})?> getCurrentPosition() async {
    final position = await _locationProviderFactory.getCurrentPosition();
    if (position == null) return null;
    return (latitude: position.latitude, longitude: position.longitude);
  }

  Future<void> _teardown() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _runId = null;
    _lastCheckpointAt = null;
    await _locationProvider?.dispose();
    _locationProvider = null;
    await _foregroundService.stop();
    await WakelockPlus.disable();
  }
}
