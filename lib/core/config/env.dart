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

  /// MapLibre style URL for the territory map (plan C3 — never the
  /// OpenStreetMap public raster tile server in production). Points at a
  /// MapLibre `style.json` — vector tiles, not raster XYZ — rendered via
  /// `maplibre_gl`'s `MapLibreMap` widget. Defaults to OpenFreeMap's
  /// "Liberty" style (free, no API key, commercial use permitted — see
  /// openfreemap.org) so the map works out of the box; override for a
  /// self-hosted or commercial style. Attribution is baked into the style
  /// document itself and rendered by the map automatically — no separate
  /// attribution string needed, unlike the old raster-tile setup.
  static String get mapStyleUrl =>
      dotenv.maybeGet('MAP_STYLE_URL') ?? 'https://tiles.openfreemap.org/styles/liberty';

  /// Optional second style URL to fall back to manually (e.g. in
  /// `.env.client`) if the primary style host has an outage — MapLibre's
  /// plugin API doesn't expose a per-tile error hook to automate this
  /// switch the way the old raster `TileLayer.errorTileCallback` did, so
  /// this is a manual override, not an automatic runtime fallback.
  static String? get mapStyleFallbackUrl => dotenv.maybeGet('MAP_STYLE_FALLBACK_URL');

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
