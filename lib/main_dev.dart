import 'main_common.dart';

/// `flutter run --flavor dev -t lib/main_dev.dart`
Future<void> main() => bootstrap(envFile: '.env.client');
