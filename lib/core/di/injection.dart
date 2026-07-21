import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// Global service locator. Each feature registers its Data/Domain bindings
/// via `@injectable`/`@lazySingleton` annotations picked up by
/// `injection.config.dart` (generated — run `dart run build_runner build`).
final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: false,
)
Future<void> configureDependencies() async => init(getIt);
