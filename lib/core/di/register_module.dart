import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sync/local/database.dart';

/// Binds third-party singletons that `injectable` can't construct itself.
/// `Supabase.initialize(...)` must have already run (see main.dart) before
/// `configureDependencies()` is called, since this getter just reaches into
/// the already-initialized singleton.
@module
abstract class RegisterModule {
  @lazySingleton
  SupabaseClient get supabaseClient => Supabase.instance.client;

  /// Opens lazily on first query (see `AppDatabase._openConnection`), so
  /// constructing the singleton here doesn't touch disk until something
  /// actually reads/writes.
  @lazySingleton
  AppDatabase get appDatabase => AppDatabase();
}
