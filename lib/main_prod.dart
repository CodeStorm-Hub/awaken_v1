import 'main_common.dart';

/// `flutter run --flavor prod -t lib/main_prod.dart`
///
/// TODO: points at the same `awaken-dev` Supabase project as dev until a
/// separate prod project is provisioned. When it is, add `.env.client.prod`
/// to pubspec.yaml's assets and pass it here instead.
Future<void> main() => bootstrap(envFile: '.env.client');
