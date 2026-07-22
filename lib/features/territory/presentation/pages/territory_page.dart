import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/injection.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../domain/entities/geo_bounds.dart';
import '../../domain/entities/territory.dart';
import '../../domain/usecases/refresh_territories.dart';
import '../../domain/usecases/watch_owned_area.dart';
import '../../domain/usecases/watch_territories.dart';
import '../widgets/territory_map_tiles.dart';
import 'active_run_page.dart';

/// Territory map (plan §6 Phase 5c, redesigned per the territory feature
/// review). Real `flutter_map` rendering of server-authoritative territory
/// polygons, now bbox-queried against the current viewport (closes the
/// review's flagged gap — was a flat most-recent-200 scan) and backed by a
/// disk tile cache + fallback provider (`ResilientTerritoryTileLayer`) so
/// the map keeps working offline or through a tile-host outage.
class TerritoryPage extends StatefulWidget {
  const TerritoryPage({super.key});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  final _mapController = MapController();
  Timer? _refreshDebounce;

  // Falls back to a neutral world view until a fix arrives — avoids
  // centering on (0,0) "null island" while permission/location resolves.
  LatLng _center = const LatLng(20, 0);
  bool _hasFix = false;
  bool _showRivalTerritory = true;

  @override
  void initState() {
    super.initState();
    unawaited(_locateSelf());
  }

  Future<void> _locateSelf() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _refreshForCurrentView();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _hasFix = true;
      });
      _mapController.move(_center, 15);
    } catch (_) {
      // Best-effort centering only — a failed/denied fix just keeps the
      // fallback view; the map (and starting a run) still works.
    } finally {
      _refreshForCurrentView();
    }
  }

  void _refreshForCurrentView() {
    final bounds = _mapController.camera.visibleBounds;
    unawaited(
      getIt<RefreshTerritories>()(
        GeoBounds(
          minLat: bounds.southWest.latitude,
          minLng: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLng: bounds.northEast.longitude,
        ),
      ),
    );
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 500), _refreshForCurrentView);
    }
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Territory',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: scheme.onSurface),
                  ),
                  Tooltip(
                    message: 'Profile',
                    child: Material(
                      color: scheme.secondaryContainer,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: Text(
                              'G',
                              style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    color: scheme.surfaceContainerLow,
                    child: Stack(
                      children: [
                        StreamBuilder<List<Territory>>(
                          stream: getIt<WatchTerritories>()(),
                          builder: (context, snapshot) {
                            final territories = snapshot.data ?? const [];
                            return _Map(
                              controller: _mapController,
                              center: _center,
                              hasFix: _hasFix,
                              territories: territories,
                              showRivalTerritory: _showRivalTerritory,
                              scheme: scheme,
                              onMapEvent: _onMapEvent,
                            );
                          },
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          right: 14,
                          child: Row(
                            children: [
                              _OwnedAreaChip(scheme: scheme),
                              const Spacer(),
                              _TerritoryLegend(scheme: scheme, showRivalTerritory: _showRivalTerritory),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _RoundIconButton(
                                    icon: Icons.my_location,
                                    tooltip: 'Center map',
                                    onTap: () => _mapController.move(_center, 15),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                    ),
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const ActiveRunPage()),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.directions_run, size: 20),
                                        SizedBox(width: 8),
                                        Text('Start run'),
                                      ],
                                    ),
                                  ),
                                  _RoundIconButton(
                                    icon: Icons.layers,
                                    tooltip: 'Map layers',
                                    onTap: () => _showLayersSheet(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLayersSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                    Text('Map layers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show rival territory'),
                      subtitle: const Text("Hide other players' captured land"),
                      value: _showRivalTerritory,
                      onChanged: (value) {
                        setSheetState(() => _showRivalTerritory = value);
                        setState(() => _showRivalTerritory = value);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Map extends StatelessWidget {
  const _Map({
    required this.controller,
    required this.center,
    required this.hasFix,
    required this.territories,
    required this.showRivalTerritory,
    required this.scheme,
    required this.onMapEvent,
  });

  final MapController controller;
  final LatLng center;
  final bool hasFix;
  final List<Territory> territories;
  final bool showRivalTerritory;
  final ColorScheme scheme;
  final void Function(MapEvent event) onMapEvent;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: hasFix ? 15 : 2,
        onMapEvent: onMapEvent,
      ),
      children: [
        if (isAnyTileProviderConfigured) const ResilientTerritoryTileLayer() else const _TilesNotConfiguredNotice(),
        PolygonLayer(
          polygons: [
            for (final territory in territories)
              if (territory.isMine || showRivalTerritory)
                for (final ring in territory.rings)
                  Polygon(
                    points: ring,
                    color: (territory.isMine ? scheme.primaryContainer : scheme.tertiaryContainer)
                        .withValues(alpha: 0.55),
                    borderColor: territory.isMine ? scheme.primary : scheme.tertiary,
                    borderStrokeWidth: 2,
                  ),
          ],
        ),
        if (hasFix)
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 22,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
        const ResilientTerritoryAttribution(),
      ],
    );
  }
}

class _TilesNotConfiguredNotice extends StatelessWidget {
  const _TilesNotConfiguredNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Anchored below the chip row rather than at the bottom of the map: the
    // bottom edge is where the floating locate/Start-run/layers control bar
    // sits, and a bottom-pinned notice there gets visually cut off/hidden
    // behind it (found via live device testing).
    return Positioned(
      top: 62,
      left: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Map tiles not configured — set MAP_TILE_URL_TEMPLATE in .env.client. '
          'Territory data still loads.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _OwnedAreaChip extends StatelessWidget {
  const _OwnedAreaChip({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: getIt<WatchOwnedArea>()(),
      builder: (context, snapshot) {
        final areaSqm = snapshot.data ?? 0;
        final label = '${(areaSqm / 1000000).toStringAsFixed(3)} km²';
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.landscape, size: 17, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
            ],
          ),
        );
      },
    );
  }
}

/// Small color-key so "which land is mine vs. a rival's" is legible without
/// having to already know the color convention — a gap in the previous
/// design (the polygon colors existed but were never explained on-screen).
class _TerritoryLegend extends StatelessWidget {
  const _TerritoryLegend({required this.scheme, required this.showRivalTerritory});

  final ColorScheme scheme;
  final bool showRivalTerritory;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: scheme.primary),
          const SizedBox(width: 5),
          Text('You', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface)),
          if (showRivalTerritory) ...[
            const SizedBox(width: 10),
            _LegendDot(color: scheme.tertiary),
            const SizedBox(width: 5),
            Text('Others', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface)),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
