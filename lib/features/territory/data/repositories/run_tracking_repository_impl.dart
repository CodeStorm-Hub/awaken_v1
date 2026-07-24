import 'dart:async';

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
import '../mappers/path_simplifier.dart';

@LazySingleton(as: RunTrackingRepository)
class RunTrackingRepositoryImpl implements RunTrackingRepository {
  RunTrackingRepositoryImpl(
    this._foregroundService,
    this._localWriter,
    this._syncWorker,
    this._db,
    this._locationProviderFactory,
  );

  final RunForegroundService _foregroundService;
  final LocalWriter _localWriter;
  final SyncWorker _syncWorker;
  final AppDatabase _db;

  /// Real GPS in production, a fixture-replaying provider in `main_e2e.dart`
  /// builds — see `RegisterModule.locationProviderFactory`.
  final LocationProviderFactory _locationProviderFactory;

  final _stateController = StreamController<RunTrackState>.broadcast();
  RunTrackState _state = const RunTrackState();

  DeadReckoningProvider? _locationProvider;
  StreamSubscription<GeoPosition>? _positionSub;
  Timer? _ticker;
  DateTime? _startedAt;

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
    await _teardown();
    _startedAt = DateTime.now();
    _emit(const RunTrackState(isTracking: true));

    await _foregroundService.start();
    await WakelockPlus.enable();

    final provider = DeadReckoningProvider(
      inner: _locationProviderFactory.create(),
      mode: DeadReckoningMode.kalman,
    );
    _locationProvider = provider;

    try {
      await provider.start();
    } on LocationPermissionDeniedException {
      _emit(_state.copyWith(isTracking: false, permissionDenied: true));
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
  }

  void _onPositionError(Object error) {
    // `DeadReckoningAccuracyExceededException` signals GPS loss exceeding
    // the safety cap (kalman_dr's terminal "position unavailable" signal) —
    // surface it as a quality drop, not a crash; tracking keeps running so
    // the moment GPS returns, `_onPosition` resumes normally.
    _emit(_state.copyWith(gpsQuality: GpsQuality.poor));
  }

  @override
  Future<void> abandonRun() async {
    await _teardown();
    _emit(const RunTrackState());
  }

  @override
  Future<RunCaptureResult> captureRun() async {
    final points = _state.points;
    final startedAt = _startedAt;
    await _teardown();

    if (points.length < 2 || startedAt == null) {
      _emit(const RunTrackState());
      return const RunCaptureResult(
        pending: false,
        accepted: false,
        rejectedReason: 'No GPS points captured',
      );
    }

    final simplified = PathSimplifier.simplify(points);
    final id = const Uuid().v4();
    final endedAt = points.last.timestamp;

    await _localWriter.insertRun(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      pointCount: simplified.length,
      pathGeoJson: PathSimplifier.toGeoJsonLineString(simplified),
    );

    // Best-effort immediate push (plan §3 — "return the delta for
    // client-side celebration UI"): if online, `SyncWorker`'s `runs`
    // special-case (`_pushRun`) calls `submit_run()` synchronously here and
    // updates the local row before this returns. If offline, the row stays
    // queued in the outbox and this just falls through to the pending case.
    await _syncWorker.drainOutbox();

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
      rejectedReason: row.rejectedReason,
    );
  }

  Future<void> _teardown() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    await _locationProvider?.dispose();
    _locationProvider = null;
    await _foregroundService.stop();
    await WakelockPlus.disable();
  }
}
