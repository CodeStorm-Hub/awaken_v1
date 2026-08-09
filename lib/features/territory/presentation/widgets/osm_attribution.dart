import 'package:flutter/material.dart';
import '../../../../core/theme/shape_tokens.dart';

/// Always-visible OSM attribution overlay, shared by `TerritoryPage` and
/// `ActiveRunPage`'s map views — OSMF's attribution guidance allows a
/// tap-to-reveal info button only for a startup splash/one-time
/// interaction; the ongoing map view itself must show attribution
/// continuously. MapLibre's `attributionButtonPosition` is a tap-behind-an-
/// info-icon control and doesn't satisfy that on its own, so both map pages
/// render this alongside it.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    // Was a hardcoded `Colors.white.withValues(alpha: 0.7)` — a bright
    // patch that clashed with the rest of the map chrome's dark glass
    // styling in dark mode (audit finding). Reading from the theme instead
    // keeps this in step with `AppleGlassContainer` and friends in both
    // brightnesses.
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.75),
        borderRadius: ShapeTokens.r4,
      ),
      child: Text(
        '© OpenStreetMap contributors',
        style: TextStyle(
          fontSize: 9,
          color: scheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
