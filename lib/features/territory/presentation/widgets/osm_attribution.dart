import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 9, color: Colors.black87),
      ),
    );
  }
}
