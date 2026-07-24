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
}

@LazySingleton(as: LocationProviderFactory)
class GeolocatorLocationProviderFactory implements LocationProviderFactory {
  @override
  LocationProvider create() => GeolocatorLocationProvider();
}
