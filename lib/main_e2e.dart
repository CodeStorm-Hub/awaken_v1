import 'features/territory/data/datasources/scripted_location_provider.dart';
import 'main_common.dart';

/// `flutter run --flavor dev -t lib/main_e2e.dart` (or an installed
/// `main_e2e`-built APK/IPA driven by Appium — see Part C2/C3 of the E2E
/// plan). Same app, same `.env.client`, only the run-tracking GPS source
/// changes: a scripted fixture replayed at real-world pace instead of live
/// GPS, so the same test script drives a deterministic loop-closure capture
/// on both the Android emulator and real iOS hardware, where XCTest has no
/// way to fake location at all.
Future<void> main() => bootstrap(
  envFile: '.env.client',
  locationProviderOverride: ScriptedLocationProviderFactory(),
);
