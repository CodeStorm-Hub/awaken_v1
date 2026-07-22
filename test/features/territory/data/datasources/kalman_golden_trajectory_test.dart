import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kalman_dr/kalman_dr.dart';

/// Golden-trajectory regression test for the `kalman_dr` smoothing pipeline
/// (plan §2.3 Moderate — "kalman_dr is a 1-like niche package... add
/// golden-trajectory unit tests against recorded GPS traces so a swap-out is
/// verifiable"). This was flagged as missing in the territory feature
/// review; it exists so a future `kalman_dr` version bump, fork, or
/// hand-rolled EKF replacement can be checked against a known-good result
/// instead of only "does it compile".
///
/// The fixture is a synthetic straight-line walking trace (not a real
/// recorded run — deterministic and reviewable beats a recorded blob
/// nobody can regenerate) with fixed, reproducible jitter (a sine wave, not
/// `Random`, so the assertions never flake) layered onto perfect
/// straight-line ground truth.
void main() {
  group('kalman_dr golden trajectory', () {
    test('smoothed output tracks the ground-truth path and reduces raw jitter', () async {
      const startLat = 37.7749;
      const startLng = -122.4194;
      const metersPerDegLat = 111320.0;
      final cosLat = math.cos(startLat * math.pi / 180);
      const speedMps = 1.4; // brisk walking pace
      const headingDeg = 90.0; // due east
      const sampleCount = 30;
      const jitterMeters = 6.0; // typical handset GPS horizontal noise

      // Ground truth: a perfectly straight east-moving line, one fix/second.
      final groundTruth = <({double lat, double lng, DateTime t})>[];
      final baseTime = DateTime.utc(2026);
      for (var i = 0; i < sampleCount; i++) {
        final distanceM = speedMps * i;
        final lng = startLng + (distanceM / (metersPerDegLat * cosLat));
        groundTruth.add((lat: startLat, lng: lng, t: baseTime.add(Duration(seconds: i))));
      }

      // Raw (jittered) fixes fed into the filter — deterministic sine-wave
      // offset instead of Random so the test never flakes.
      double jitterMetersAt(int i) => jitterMeters * math.sin(i * 0.9);

      final fake = _ScriptedLocationProvider();
      final provider = DeadReckoningProvider(inner: fake, mode: DeadReckoningMode.kalman);
      final smoothed = <GeoPosition>[];
      final sub = provider.positions.listen(smoothed.add);

      await provider.start();
      for (var i = 0; i < groundTruth.length; i++) {
        final g = groundTruth[i];
        final jitterLng = jitterMetersAt(i) / (metersPerDegLat * cosLat);
        fake.emit(
          GeoPosition(
            latitude: g.lat,
            longitude: g.lng + jitterLng,
            accuracy: jitterMeters,
            speed: speedMps,
            heading: headingDeg,
            timestamp: g.t,
          ),
        );
        // Let the broadcast stream's listener fire before the next fix.
        await Future<void>.delayed(Duration.zero);
      }
      await sub.cancel();
      await provider.dispose();

      expect(smoothed.length, groundTruth.length, reason: 'one smoothed fix per raw fix (no drops in kalman mode)');

      double deviationMeters(GeoPosition p, ({double lat, double lng, DateTime t}) truth) {
        final dLat = (p.latitude - truth.lat) * metersPerDegLat;
        final dLng = (p.longitude - truth.lng) * metersPerDegLat * cosLat;
        return math.sqrt(dLat * dLat + dLng * dLng);
      }

      final rawDeviations = [for (var i = 0; i < groundTruth.length; i++) jitterMetersAt(i).abs()];
      final smoothedDeviations = [
        for (var i = 0; i < groundTruth.length; i++) deviationMeters(smoothed[i], groundTruth[i]),
      ];

      // Skip the first few fixes — the filter hasn't converged from its
      // initial state yet, so an early-sample comparison isn't meaningful.
      const warmup = 5;
      final avgRaw = rawDeviations.skip(warmup).reduce((a, b) => a + b) / (rawDeviations.length - warmup);
      final avgSmoothed =
          smoothedDeviations.skip(warmup).reduce((a, b) => a + b) / (smoothedDeviations.length - warmup);

      expect(
        avgSmoothed,
        lessThan(avgRaw),
        reason: 'the whole point of the filter is to be closer to ground truth than the raw noisy input',
      );
      expect(
        smoothedDeviations.last,
        lessThan(jitterMeters),
        reason: 'converged smoothed position should beat a single raw jittered fix',
      );
      expect(smoothed.last.accuracy.isFinite, isTrue);
    });
  });
}

/// A [LocationProvider] the test drives manually via [emit] — no timers, no
/// platform channels, fully synchronous/deterministic.
class _ScriptedLocationProvider implements LocationProvider {
  final _controller = StreamController<GeoPosition>.broadcast();

  @override
  Stream<GeoPosition> get positions => _controller.stream;

  void emit(GeoPosition position) => _controller.add(position);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
