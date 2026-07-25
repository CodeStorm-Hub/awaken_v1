import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../../domain/entities/geo_bounds.dart';
import '../../domain/entities/territory.dart';
import '../../domain/usecases/get_current_position.dart';
import '../../domain/usecases/refresh_territories.dart';
import '../../domain/usecases/watch_owned_area.dart';
import '../../domain/usecases/watch_territories.dart';
import '../widgets/territory_map_style.dart';
import 'active_run_page.dart';

/// Territory map (plan §6 Phase 5c, redesigned per the territory feature
/// review). Real vector-tile rendering via `maplibre_gl` — replaces the
/// earlier `flutter_map` raster setup, which couldn't consume OpenFreeMap's
/// tiles (vector-only) without a much larger integration. The `MapLibreMap`
/// widget is built exactly once and never rebuilt from state changes;
/// territory polygons/markers are synced onto it *imperatively* via the
/// controller (`addFill`/`removeFills`) so the native map view is never
/// torn down and re-created — that rebuild-on-every-change pattern was the
/// direct cause of this page's earlier map/GPS-page choppiness.
class TerritoryPage extends StatefulWidget {
  const TerritoryPage({super.key});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  MapLibreMapController? _controller;
  StreamSubscription<List<Territory>>? _territoriesSub;
  final _fillsByTerritoryId = <String, List<Fill>>{};
  List<Territory> _lastTerritories = const [];

  LatLng _center = const LatLng(20, 0);
  bool _hasFix = false;
  bool _showRivalTerritory = true;

  @override
  void initState() {
    super.initState();
    unawaited(_locateSelf());
  }

  @override
  void dispose() {
    unawaited(_territoriesSub?.cancel());
    super.dispose();
  }

  Future<void> _locateSelf() async {
    try {
      final position = await getIt<GetCurrentPosition>()(const NoParams());
      if (position == null || !mounted) return;
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _hasFix = true;
      });
      final controller = _controller;
      if (controller != null) {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(_center, 15));
        await _syncCurrentPositionMarker();
      }
    } catch (_) {
      // Best-effort centering only — a failed/denied fix just keeps the
      // fallback view; the map (and starting a run) still works.
    }
  }

  Circle? _positionMarker;

  Future<void> _syncCurrentPositionMarker() async {
    final controller = _controller;
    if (controller == null || !_hasFix) return;
    final scheme = Theme.of(context).colorScheme;
    if (_positionMarker == null) {
      _positionMarker = await controller.addCircle(
        CircleOptions(
          geometry: _center,
          circleRadius: 7,
          circleColor: _colorToHex(scheme.primary),
          circleStrokeColor: _colorToHex(scheme.surface),
          circleStrokeWidth: 2,
        ),
      );
    } else {
      await controller.updateCircle(
        _positionMarker!,
        CircleOptions(geometry: _center),
      );
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    if (_hasFix) {
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(_center, 15));
      await _syncCurrentPositionMarker();
    }
    await _refreshForCurrentView();
    _territoriesSub = getIt<WatchTerritories>()().listen(_onTerritoriesChanged);
  }

  void _onTerritoriesChanged(List<Territory> territories) {
    _lastTerritories = territories;
    unawaited(_redrawFills());
  }

  Future<void> _redrawFills() async {
    final controller = _controller;
    if (controller == null) return;
    final scheme = Theme.of(context).colorScheme;

    final allFills = _fillsByTerritoryId.values.expand((f) => f).toList();
    if (allFills.isNotEmpty) {
      await controller.removeFills(allFills);
    }
    _fillsByTerritoryId.clear();

    for (final territory in _lastTerritories) {
      if (!territory.isMine && !_showRivalTerritory) continue;
      final rings = TerritoryMapStyle.territoryRingsToLatLng(territory);
      final fills = <Fill>[];
      for (final ring in rings) {
        final fill = await controller.addFill(
          FillOptions(
            geometry: [ring],
            fillColor: _colorToHex(
              territory.isMine ? scheme.primary : scheme.tertiary,
            ),
            fillOpacity: 0.45,
            fillOutlineColor: _colorToHex(
              territory.isMine ? scheme.primary : scheme.tertiary,
            ),
          ),
        );
        fills.add(fill);
      }
      _fillsByTerritoryId[territory.id] = fills;
    }
  }

  Future<void> _refreshForCurrentView() async {
    final controller = _controller;
    if (controller == null) return;
    final bounds = await controller.getVisibleRegion();
    unawaited(
      getIt<RefreshTerritories>()(
        GeoBounds(
          minLat: bounds.southwest.latitude,
          minLng: bounds.southwest.longitude,
          maxLat: bounds.northeast.latitude,
          maxLng: bounds.northeast.longitude,
        ),
      ),
    );
  }

  Future<void> _recenter() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(_center, 15));
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
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  const CurrentUserAvatarButton(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      MapLibreMap(
                        styleString: Env.mapStyleUrl,
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(20, 0),
                          zoom: 2,
                        ),
                        onMapCreated: _onMapCreated,
                        onStyleLoadedCallback: _onStyleLoaded,
                        onCameraIdle: () => unawaited(_refreshForCurrentView()),
                        myLocationEnabled: false,
                        logoEnabled: false,
                        attributionButtonPosition:
                            AttributionButtonPosition.bottomLeft,
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: Row(
                          children: [
                            _OwnedAreaChip(scheme: scheme),
                            const Spacer(),
                            _TerritoryLegend(
                              scheme: scheme,
                              showRivalTerritory: _showRivalTerritory,
                            ),
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RoundIconButton(
                                  icon: Icons.my_location,
                                  tooltip: 'Center map',
                                  onTap: _recenter,
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ActiveRunPage(),
                                    ),
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
                                // A badge dot when a non-default filter is
                                // active (rival territory hidden) — found in
                                // design critique: the icon alone gave no
                                // indication of the current layers state.
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _RoundIconButton(
                                      icon: Icons.layers,
                                      tooltip: _showRivalTerritory
                                          ? 'Map layers'
                                          : 'Map layers (rival territory hidden)',
                                      onTap: () => _showLayersSheet(context),
                                    ),
                                    if (!_showRivalTerritory)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: scheme.tertiary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  scheme.surfaceContainerHigh,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Map layers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show rival territory'),
                      subtitle: const Text("Hide other players' captured land"),
                      value: _showRivalTerritory,
                      onChanged: (value) {
                        setSheetState(() => _showRivalTerritory = value);
                        setState(() => _showRivalTerritory = value);
                        unawaited(_redrawFills());
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

String _colorToHex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2)}';
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.landscape, size: 17, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TerritoryLegend extends StatelessWidget {
  const _TerritoryLegend({
    required this.scheme,
    required this.showRivalTerritory,
  });

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
          Text(
            'You',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          if (showRivalTerritory) ...[
            const SizedBox(width: 10),
            _LegendDot(color: scheme.tertiary),
            const SizedBox(width: 5),
            Text(
              'Others',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
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
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The `tooltip` field was accepted but never actually used — no
    // `Tooltip`, no `Semantics` label anywhere — so the locate/layers
    // buttons had zero accessible name for TalkBack. Found in accessibility
    // review. `Tooltip` both shows on long-press and supplies the
    // Semantics label, so it fixes both the visual and a11y gap at once.
    return Tooltip(
      message: tooltip,
      child: Material(
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
      ),
    );
  }
}
