import 'main_dev.dart' as main_dev;

/// Convenience entrypoint so plain `flutter run`/`flutter test` still work
/// without `--flavor`/`-t`. Prefer `flutter run --flavor dev -t lib/main_dev.dart`
/// (or `prod`) once flavor-specific behavior diverges.
Future<void> main() => main_dev.main();
