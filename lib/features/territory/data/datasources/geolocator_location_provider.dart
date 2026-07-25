import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:kalman_dr/kalman_dr.dart';

import '../../domain/repositories/run_tracking_repository.dart';

/// Adapts `geolocator`'s position stream to `kalman_dr`'s [LocationProvider]
/// interface, so it can be wrapped in a [DeadReckoningProvider] for
/// EKF-smoothed positions (plan §2.3 — kalman_dr golden-trajectory
/// requirement is a follow-up; this is the live-GPS feed side).
class GeolocatorLocationProvider implements LocationProvider {
  StreamSubscription<Position>? _positionSub;
  StreamController<GeoPosition>? _controller;

  @override
  Stream<GeoPosition> get positions {
    _controller ??= StreamController<GeoPosition>.broadcast();
    return _controller!.stream;
  }

  @override
  Future<void> start() async {
    final permission = await _ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException();
    }

    await _positionSub?.cancel();
    _controller ??= StreamController<GeoPosition>.broadcast();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ),
    ).listen(_onPosition, onError: (Object e) => _controller?.addError(e));
  }

  void _onPosition(Position position) {
    // Anti-spoof client gate (plan H7, layered anti-cheat): discard fixes
    // the platform itself flags as coming from a mock-location provider.
    // Authoritative velocity/teleport checks stay server-side in
    // `submit_run()` — this is only the cheap client-side pre-filter.
    if (position.isMocked) return;
    _controller?.add(
      GeoPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        timestamp: position.timestamp,
      ),
    );
  }

  Future<LocationPermission> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  @override
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller?.close();
    _controller = null;
  }
}
