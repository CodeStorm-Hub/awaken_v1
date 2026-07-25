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
    final position = await geolocator.Geolocator.getCurrentPosition(
      locationSettings: const geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.medium,
      ),
    );
    return GeoPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
    );
  }
}
