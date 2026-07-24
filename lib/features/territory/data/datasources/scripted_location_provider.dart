import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kalman_dr/kalman_dr.dart';

import 'location_provider_factory.dart';

/// Passed to `bootstrap(locationProviderOverride: ...)` by `main_e2e.dart`.
class ScriptedLocationProviderFactory implements LocationProviderFactory {
  @override
  LocationProvider create() => ScriptedLocationProvider();
}

/// Replays a bundled JSON fixture of GPS waypoints on a real-world-paced
/// [Timer], standing in for [GeolocatorLocationProvider] in E2E builds only
/// (see `main_e2e.dart`).
///
/// This exists because Apple's XCTest framework has no location-simulation
/// API for real iOS hardware — `mobile: setLocation` isn't implementable
/// there the way it is on Android — so a fixture replayed entirely inside
/// the app is the only way to get a deterministic, repeatable loop-closure
/// path on both platforms from the same Appium test script. It also
/// sidesteps `GeolocatorLocationProvider`'s `position.isMocked` filter
/// (plan H7 anti-spoof gate), which would otherwise discard `adb emu geo
/// fix`-style fixes outright.
class ScriptedLocationProvider implements LocationProvider {
  ScriptedLocationProvider({
    this.assetPath = 'assets/e2e/scripted_run_fixture.json',
  });

  final String assetPath;

  final _controller = StreamController<GeoPosition>.broadcast();
  final _timers = <Timer>[];

  @override
  Stream<GeoPosition> get positions => _controller.stream;

  @override
  Future<void> start() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final accuracy = (json['accuracyMeters'] as num).toDouble();
    final waypoints = (json['waypoints'] as List).cast<Map<String, dynamic>>();

    final startedAt = DateTime.now();
    for (var i = 0; i < waypoints.length; i++) {
      final w = waypoints[i];
      final offsetMs = (w['tOffsetMs'] as num).toInt();
      final timer = Timer(Duration(milliseconds: offsetMs), () {
        if (_controller.isClosed) return;
        _controller.add(
          GeoPosition(
            latitude: (w['lat'] as num).toDouble(),
            longitude: (w['lng'] as num).toDouble(),
            accuracy: accuracy,
            speed: 0,
            heading: 0,
            timestamp: startedAt.add(Duration(milliseconds: offsetMs)),
          ),
        );
      });
      _timers.add(timer);
    }
  }

  @override
  Future<void> stop() async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
