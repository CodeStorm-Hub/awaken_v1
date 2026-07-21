import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thin wrapper over the bundled `.env.client` asset (see pubspec.yaml).
/// Only client-safe values live here — see `.env.client`'s header comment
/// for what must never be added.
///
/// [fileName] lets flavor entrypoints (main_dev.dart/main_prod.dart) select
/// a different bundled env file. Only `.env.client` exists today — there is
/// one Supabase project (`awaken-dev`). When a separate prod project is
/// provisioned, add `.env.client.prod` to pubspec.yaml's assets and pass it
/// from main_prod.dart.
abstract final class Env {
  static Future<void> load({String fileName = '.env.client'}) =>
      dotenv.load(fileName: fileName);

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabasePublishableKey =>
      _require('SUPABASE_PUBLISHABLE_KEY');

  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env var "$key". Copy .env.client.example to '
        '.env.client and fill in real values.',
      );
    }
    return value;
  }
}
