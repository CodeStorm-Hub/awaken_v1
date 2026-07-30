import 'main_common.dart';

/// `flutter run --flavor prod -t lib/main_prod.dart`
///
/// `awaken-dev` is the only Supabase project — dev and prod builds
/// intentionally share it, no separate prod project.
Future<void> main() => bootstrap(envFile: '.env.client');
