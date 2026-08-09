import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/shape_tokens.dart';

/// "Map layers" bottom sheet — toggles for rival-territory visibility, the
/// squad heatmap, and the capture-activity heatmap. Owns its own local
/// switch state (so the sheet's UI updates immediately on tap, same as the
/// `StatefulBuilder` this replaced) and calls back into `TerritoryPage`'s
/// state for both the outer `setState` and the actual map redraw — this
/// widget never touches a `MapLibreMapController` itself.
class TerritoryLayersSheet extends StatefulWidget {
  const TerritoryLayersSheet({
    super.key,
    required this.showRivalTerritory,
    required this.onShowRivalTerritoryChanged,
    required this.showSquadHeatmap,
    required this.onShowSquadHeatmapChanged,
    required this.hasSquad,
    required this.showCaptureHeatmap,
    required this.onShowCaptureHeatmapChanged,
  });

  final bool showRivalTerritory;
  final ValueChanged<bool> onShowRivalTerritoryChanged;
  final bool showSquadHeatmap;
  final ValueChanged<bool> onShowSquadHeatmapChanged;
  final bool hasSquad;
  final bool showCaptureHeatmap;
  final ValueChanged<bool> onShowCaptureHeatmapChanged;

  @override
  State<TerritoryLayersSheet> createState() => _TerritoryLayersSheetState();
}

class _TerritoryLayersSheetState extends State<TerritoryLayersSheet> {
  late var _showRivalTerritory = widget.showRivalTerritory;
  late var _showSquadHeatmap = widget.showSquadHeatmap;
  late var _showCaptureHeatmap = widget.showCaptureHeatmap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: SafeArea(
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
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: ShapeTokens.pill,
                  ),
                ),
              ),
              Text(
                'Map layers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // `SwitchListTile` paints its background/ink splashes on the
              // nearest `Material` ancestor — without this, the enclosing
              // glass `Container`'s `DecoratedBox` swallows them and taps
              // show no visual feedback at all.
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Show rival territory',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Hide other players' captured land",
                    style: TextStyle(color: secondaryLabelColor(context)),
                  ),
                  value: _showRivalTerritory,
                  onChanged: (value) {
                    setState(() => _showRivalTerritory = value);
                    widget.onShowRivalTerritoryChanged(value);
                  },
                ),
              ),
              // Squad territory heatmap (item 11) — an aggregated overlay
              // of every squad member's owned territory. Disabled with an
              // explanatory subtitle rather than hidden entirely when the
              // caller isn't in a squad, so the layer's existence isn't a
              // surprise once they join one.
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Squad territory heatmap',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    widget.hasSquad
                        ? "Highlight your squad's combined turf"
                        : 'Join a squad to highlight its combined turf',
                    style: TextStyle(color: secondaryLabelColor(context)),
                  ),
                  value: _showSquadHeatmap,
                  onChanged: widget.hasSquad
                      ? (value) {
                          setState(() => _showSquadHeatmap = value);
                          widget.onShowSquadHeatmapChanged(value);
                        }
                      : null,
                ),
              ),
              // Capture-density heatmap (item 4) — recent captures across
              // all users, not just this caller's squad, so (unlike the
              // squad heatmap above) it's never gated on squad membership.
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Capture activity heatmap',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Highlight where territory is changing hands',
                    style: TextStyle(color: secondaryLabelColor(context)),
                  ),
                  value: _showCaptureHeatmap,
                  onChanged: (value) {
                    setState(() => _showCaptureHeatmap = value);
                    widget.onShowCaptureHeatmapChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
