import 'dart:async';

import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:injectable/injectable.dart';
import 'package:kalman_dr/kalman_dr.dart';

import 'geolocator_location_provider.dart';

/// Indirection so `RunTrackingRepositoryImpl` doesn't construct
/// `GeolocatorLocationProvider` directly — `main_e2e.dart` re-registers this
/// with `ScriptedLocationProviderFactory` instead (see `scripted_location_provider.dart`).
/// A class rather than a bare `LocationProvider Function()` typedef, because
/// `injectable`'s generator can't resolve raw function types ("is not a
/// class element") even through a typedef alias.
abstract class LocationProviderFactory {
  LocationProvider create();

  /// A single best-effort fix, for one-time uses like centering the
  /// territory map on open — distinct from [create]'s continuous stream,
  /// which is for active run tracking. Returns `null` on denied permission
  /// or a failed fix; callers treat this as advisory only. Boundary fix:
  /// `TerritoryPage` previously called `package:geolocator` directly for
  /// this instead of going through the domain's location abstraction like
  /// every other territory location access does.
  Future<GeoPosition?> getCurrentPosition();
}

@LazySingleton(as: LocationProviderFactory)
class GeolocatorLocationProviderFactory implements LocationProviderFactory {
  @override
  LocationProvider create() => GeolocatorLocationProvider();

  @override
  Future<GeoPosition?> getCurrentPosition() async {
    var permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
    }
    if (permission == geolocator.LocationPermission.denied ||
        permission == geolocator.LocationPermission.deniedForever) {
      return null;
    }

    // Real bug found live: this used to call `Geolocator.getCurrentPosition()`
    // directly, which on Android is allowed to return a cached recent fix
    // from `FusedLocationProviderClient` rather than forcing a new
    // acquisition — that showed up as `TerritoryPage` centering on a
    // completely different location than what `ActiveRunPage` displayed
    // seconds later for the *same* device, since `ActiveRunPage` reads a
    // continuous position stream (via [create]) instead. Routing this
    // one-shot call through the exact same [LocationProvider] stream —
    // taking its first emission — means both screens always read from the
    // identical underlying source, so they can no longer disagree.
    final provider = create();
    try {
      await provider.start();
    } catch (_) {
      await provider.dispose();
      return null;
    }
    final completer = Completer<GeoPosition?>();
    late final StreamSubscription<GeoPosition> subscription;
    subscription = provider.positions.listen(
      (position) {
        if (!completer.isCompleted) completer.complete(position);
      },
      onError: (Object _) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    try {
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
    } finally {
      await subscription.cancel();
      await provider.dispose();
    }
  }
}
