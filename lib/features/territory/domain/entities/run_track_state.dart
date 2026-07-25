import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'gps_quality.dart';
import 'track_point.dart';

/// Live state of an in-progress run (plan §6 Phase 5). Emitted by
/// `RunTrackingRepository.watchRunState()` — presentation never talks to
/// geolocator/kalman_dr directly.
class RunTrackState extends Equatable {
  const RunTrackState({
    this.isTracking = false,
    this.points = const [],
    this.elapsed = Duration.zero,
    this.distanceMeters = 0,
    this.gpsQuality = GpsQuality.none,
    this.permissionDenied = false,
    this.startFailed = false,
  });

  final bool isTracking;
  final List<TrackPoint> points;
  final Duration elapsed;
  final double distanceMeters;
  final GpsQuality gpsQuality;

  /// Location permission was denied when `startRun()` was called.
  final bool permissionDenied;

  /// `startRun()` threw after permission was already granted — e.g. the
  /// foreground service or wakelock failed to start. Distinct from
  /// [permissionDenied]: this is a device/OS-level failure, not a user
  /// choice, so the UI should offer retry rather than a settings deep-link.
  final bool startFailed;

  /// A loop only counts as closed once the run has covered the plan's
  /// minimum length — otherwise the very first fix (start == "current
  /// position") would trivially satisfy the closure radius check.
  bool get isLoopClosed {
    if (points.length < 2 || distanceMeters < _minLoopLengthMeters) return false;
    final start = points.first;
    final current = points.last;
    return _haversineMeters(start, current) <= _loopClosureRadiusMeters;
  }

  RunTrackState copyWith({
    bool? isTracking,
    List<TrackPoint>? points,
    Duration? elapsed,
    double? distanceMeters,
    GpsQuality? gpsQuality,
    bool? permissionDenied,
    bool? startFailed,
  }) {
    return RunTrackState(
      isTracking: isTracking ?? this.isTracking,
      points: points ?? this.points,
      elapsed: elapsed ?? this.elapsed,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      gpsQuality: gpsQuality ?? this.gpsQuality,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      startFailed: startFailed ?? this.startFailed,
    );
  }

  @override
  List<Object?> get props =>
      [isTracking, points, elapsed, distanceMeters, gpsQuality, permissionDenied, startFailed];
}

// Mirrors AppConstants.loopClosureRadiusMeters/minRunLengthMeters — kept as
// private literals here to avoid a domain->core/constants coupling for a
// pure-entity getter; both call sites derive from the same plan §3 values.
const _loopClosureRadiusMeters = 30.0;
const _minLoopLengthMeters = 400.0;

double _haversineMeters(TrackPoint a, TrackPoint b) {
  const earthRadiusM = 6371000.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLon = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);
  final h = _sin2(dLat / 2) + math.cos(lat1) * math.cos(lat2) * _sin2(dLon / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(h));
}

double _degToRad(double deg) => deg * (math.pi / 180);
double _sin2(double x) => math.sin(x) * math.sin(x);
