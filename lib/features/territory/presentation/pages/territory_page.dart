import 'package:flutter/material.dart';

import '../../../profile/presentation/pages/profile_page.dart';
import 'active_run_page.dart';

/// Territory map (Claude Design handoff — `isTerritory`). No Territory
/// feature exists in the codebase yet, though Supabase already has a real
/// `territories` table + `submit_run()` RPC (see CLAUDE.md) — wiring this
/// screen to that backend (real GPS capture, PostGIS polygon rendering) is
/// a separate, much larger effort than matching the design's UI. This is
/// presentation-only: the grid/blobs/markers below are static concept
/// dressing, same as the handoff's own mocked polygons.
class TerritoryPage extends StatelessWidget {
  const TerritoryPage({super.key});

  static const _polygons = [
    (left: 0.08, top: 0.16, width: 0.34, height: 0.26, radius: 42.0, tertiary: false),
    (left: 0.46, top: 0.46, width: 0.30, height: 0.22, radius: 55.0, tertiary: false),
    (left: 0.62, top: 0.10, width: 0.24, height: 0.20, radius: 999.0, tertiary: true),
  ];

  static const _squadDots = [
    (left: 0.70, top: 0.55, initial: 'P'),
    (left: 0.30, top: 0.65, initial: 'M'),
  ];

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
                        Positioned.fill(child: CustomPaint(painter: _StreetGridPainter(color: scheme.outlineVariant))),
                        for (final poly in _polygons)
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.topLeft,
                              widthFactor: 1,
                              heightFactor: 1,
                              child: Align(
                                alignment: Alignment(poly.left * 2 - 1, poly.top * 2 - 1),
                                child: FractionallySizedBox(
                                  widthFactor: poly.width,
                                  heightFactor: poly.height,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: (poly.tertiary ? scheme.tertiaryContainer : scheme.primaryContainer)
                                          .withValues(alpha: poly.tertiary ? 0.55 : 0.7),
                                      borderRadius: BorderRadius.circular(poly.radius),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (final dot in _squadDots)
                          Align(
                            alignment: Alignment(dot.left * 2 - 1, dot.top * 2 - 1),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: scheme.tertiary,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3)],
                              ),
                              child: Center(
                                child: Text(
                                  dot.initial,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onTertiary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: const Alignment(-0.12, 0.04),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.surface, width: 3),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
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
                                Text(
                                  '0.21 km² captured',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 16,
                          child: Text(
                            'Map data placeholder',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
                                  _RoundIconButton(icon: Icons.my_location, tooltip: 'Center map', onTap: () {}),
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

class _StreetGridPainter extends CustomPainter {
  const _StreetGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 34.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StreetGridPainter oldDelegate) => oldDelegate.color != color;
}
