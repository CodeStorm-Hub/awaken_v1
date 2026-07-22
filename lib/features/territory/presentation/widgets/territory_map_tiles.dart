import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import '../../../../core/config/env.dart';

/// Single FMTC store shared by every map on the territory feature (the
/// active-run trace and the territories overview) — one on-disk cache, not
/// one per screen, so a tile viewed on one screen is already cached for the
/// other. Created once in `main_common.dart`'s bootstrap.
const territoryTileStoreName = 'territoryTiles';

/// Whether at least one tile source (primary or fallback) is configured —
/// mirrors the previous `TerritoryPage` check so the "map tiles not
/// configured" notice still shows correctly when neither is set.
bool get isAnyTileProviderConfigured =>
    (Env.mapTileUrlTemplate?.isNotEmpty ?? false) || (Env.mapTileFallbackUrlTemplate?.isNotEmpty ?? false);

/// Whether the app has fallen back to the secondary tile provider — shared
/// (not per-widget-instance) state so `ResilientTerritoryAttribution` shows
/// the *actually active* provider's attribution even though it has no
/// direct reference to whichever `ResilientTerritoryTileLayer` triggered the
/// switch. Process-lifetime, not persisted: a fresh app launch always
/// retries the primary first.
final ValueNotifier<bool> _usingFallbackTiles = ValueNotifier(false);

/// A raster `TileLayer` that (1) persists tiles to disk via FMTC — so
/// previously-viewed areas keep rendering offline or if the tile host is
/// down (territory review gap #3), and (2) falls back to a second free-tier
/// provider if the primary starts failing to load tiles (neither MapTiler
/// nor OpenFreeMap-class free hosts commit to an uptime SLA — see
/// `Env.mapTileFallbackUrlTemplate`'s doc comment).
///
/// Once a fallback switch happens it stays switched for the app session (no
/// flapping back to a primary that might still be degraded).
class ResilientTerritoryTileLayer extends StatefulWidget {
  const ResilientTerritoryTileLayer({super.key});

  @override
  State<ResilientTerritoryTileLayer> createState() => _ResilientTerritoryTileLayerState();
}

class _ResilientTerritoryTileLayerState extends State<ResilientTerritoryTileLayer> {
  static const _failureThreshold = 4;

  int _consecutiveFailures = 0;

  String? get _activeUrl {
    final primary = Env.mapTileUrlTemplate;
    final fallback = Env.mapTileFallbackUrlTemplate;
    if (_usingFallbackTiles.value && fallback != null && fallback.isNotEmpty) return fallback;
    if (primary != null && primary.isNotEmpty) return primary;
    return fallback;
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (_usingFallbackTiles.value) return;
    final fallback = Env.mapTileFallbackUrlTemplate;
    if (fallback == null || fallback.isEmpty) return;

    _consecutiveFailures++;
    if (_consecutiveFailures >= _failureThreshold) {
      _usingFallbackTiles.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _usingFallbackTiles,
      builder: (context, _, _) {
        final url = _activeUrl;
        if (url == null) return const SizedBox.shrink();
        return TileLayer(
          key: ValueKey(url),
          urlTemplate: url,
          userAgentPackageName: 'com.awaken.awaken',
          tileProvider: FMTCTileProvider(
            stores: const {territoryTileStoreName: BrowseStoreStrategy.readUpdateCreate},
          ),
          errorTileCallback: _onTileError,
        );
      },
    );
  }
}

/// Attribution text tied to whichever tile source is currently active.
/// Exposed separately so callers can position it themselves (both
/// `TerritoryPage` and `ActiveRunPage` want it in different spots).
class ResilientTerritoryAttribution extends StatelessWidget {
  const ResilientTerritoryAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isAnyTileProviderConfigured) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: _usingFallbackTiles,
      builder: (context, usingFallback, _) {
        final text = usingFallback ? Env.mapTileFallbackAttribution : Env.mapTileAttribution;
        return SimpleAttributionWidget(source: Text(text));
      },
    );
  }
}
