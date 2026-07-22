import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/env.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../domain/entities/territory.dart';
import '../../domain/usecases/refresh_territories.dart';
import '../../domain/usecases/watch_owned_area.dart';
import '../../domain/usecases/watch_territories.dart';
import 'active_run_page.dart';

/// Territory map (plan §6 Phase 5c). Real `flutter_map` rendering of
/// server-authoritative territory polygons, replacing the fully-static
/// painted mock this page used to show. Tile source is a free-tier
/// commercial/self-hosted provider configured via `.env.client` (plan C3 —
/// never the OSM public tile server); if unconfigured, the map still renders
/// polygons/markers over a plain background with an inline notice instead of
/// silently showing a blank map.
class TerritoryPage extends StatefulWidget {
  const TerritoryPage({super.key});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  final _mapController = MapController();

  // Falls back to a neutral world view until a fix arrives — avoids
  // centering on (0,0) "null island" while permission/location resolves.
  LatLng _center = const LatLng(20, 0);
  bool _hasFix = false;

  @override
  void initState() {
    super.initState();
    unawaited(getIt<RefreshTerritories>()(const NoParams()));
    unawaited(_locateSelf());
  }

  Future<void> _locateSelf() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
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
    }
  }

  @override
  void dispose() {
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
                              scheme: scheme,
                            );
                          },
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: _OwnedAreaChip(scheme: scheme),
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
                                  _RoundIconButton(icon: Icons.layers, tooltip: 'Map layers', onTap: () {}),
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
}

class _Map extends StatelessWidget {
  const _Map({
    required this.controller,
    required this.center,
    required this.hasFix,
    required this.territories,
    required this.scheme,
  });

  final MapController controller;
  final LatLng center;
  final bool hasFix;
  final List<Territory> territories;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final tileUrl = Env.mapTileUrlTemplate;

    return FlutterMap(
      mapController: controller,
      options: MapOptions(initialCenter: center, initialZoom: hasFix ? 15 : 2),
      children: [
        if (tileUrl != null && tileUrl.isNotEmpty)
          TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.awaken.awaken')
        else
          const _TilesNotConfiguredNotice(),
        PolygonLayer(
          polygons: [
            for (final territory in territories)
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
        if (tileUrl != null && tileUrl.isNotEmpty)
          SimpleAttributionWidget(source: Text(Env.mapTileAttribution)),
      ],
    );
  }
}

class _TilesNotConfiguredNotice extends StatelessWidget {
  const _TilesNotConfiguredNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 10,
      left: 16,
      right: 16,
      child: Text(
        'Map tiles not configured — set MAP_TILE_URL_TEMPLATE in .env.client. '
        'Territory data still loads.',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
        final label = '${(areaSqm / 1000000).toStringAsFixed(3)} km² captured';
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)],
          ),
          child: Row(
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
