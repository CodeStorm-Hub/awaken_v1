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

  /// Tile provider URL template for the territory map (plan C3 — never the
  /// OpenStreetMap public tile server in production). Optional: unset until
  /// a free-tier provider (MapTiler/Stadia/Thunderforest) key is
  /// provisioned, in which case `TerritoryPage` shows a "map tiles not
  /// configured" state instead of a blank/broken map. Include the API key
  /// directly in the URL template (most providers' convention), e.g.
  /// `https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=XXX`.
  static String? get mapTileUrlTemplate => dotenv.maybeGet('MAP_TILE_URL_TEMPLATE');

  static String get mapTileAttribution =>
      dotenv.maybeGet('MAP_TILE_ATTRIBUTION') ?? 'Map data © contributors';

  /// Web/server OAuth client id (Google Cloud Console "Web application"
  /// type) — this is the audience `GoogleSignIn.instance.initialize`'s
  /// `serverClientId` needs so the resulting ID token is accepted by
  /// Supabase's `linkIdentityWithIdToken`. Optional: null until a real
  /// Google Cloud project + Supabase Google provider are configured (an
  /// unavoidable manual/dashboard step — same class of gap as this
  /// project's other "needs a human in a console somewhere" notes).
  static String? get googleOAuthClientId => dotenv.maybeGet('GOOGLE_OAUTH_CLIENT_ID');

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
