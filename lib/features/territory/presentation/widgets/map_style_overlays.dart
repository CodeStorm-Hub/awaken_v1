import 'package:flutter/material.dart';

import '../../../../core/theme/semantic_colors.dart';

/// Blocking overlay shown once every configured style tier
/// ([MapStyleLoader]) has timed out. Offers a manual retry rather than
/// leaving the user on a dead-end blank map.
class MapStyleFailureOverlay extends StatelessWidget {
  const MapStyleFailureOverlay({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: scheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 40,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  "Couldn't load the map — check your connection.",
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small non-blocking banner shown while a fallback tier is being tried
/// after the primary style timed out — distinct from the terminal failure
/// overlay so a working-but-degraded fallback doesn't look identical to a
/// fully broken map.
class MapStyleRetryingBanner extends StatelessWidget {
  // `top`/`bottom` are mutually exclusive, matching `Positioned`'s own
  // constraints — pass whichever edge this page wants to anchor to.
  // Defaults to `bottom: 48` (the original, still-correct anchor for
  // `ActiveRunPage`, which has no chrome below the map to clear).
  // `TerritoryPage` passes `top` instead, to sit below its own top bar —
  // it previously wrapped this widget in a *second* `Positioned`, which
  // doesn't compose (both `Positioned`s tried to write `StackParentData`
  // to the same underlying map `Stack`, throwing
  // "Incorrect use of ParentDataWidget" on every build once a retry
  // banner was shown).
  const MapStyleRetryingBanner({this.top, this.bottom, super.key})
    : assert(
        top == null || bottom == null,
        'pass only one of top/bottom',
      );

  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: top,
      bottom: top == null ? (bottom ?? 48) : null,
      left: 14,
      right: 14,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Map host unreachable — trying a fallback...',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent (never auto-dismissing) indicator shown whenever
/// `MapStyleLoader.isDegradedFallback` is true — i.e. the loader gave up on
/// the primary/hosted-fallback style hosts and settled on the bundled,
/// low-zoom offline extract. Audit finding: `onStyleLoaded()` flips
/// `status` to `loaded` as soon as *any* tier finishes, including this one,
/// so [MapStyleRetryingBanner] disappears the instant the degraded tier
/// starts rendering — leaving the user with no ongoing signal that the map
/// they're looking at is missing most detail. Unlike that banner, this chip
/// stays up for as long as [MapStyleLoader.isDegradedFallback] is true, not
/// just while a retry is in flight.
class MapDegradedModeChip extends StatelessWidget {
  const MapDegradedModeChip({this.top, this.bottom, super.key})
    : assert(top == null || bottom == null, 'pass only one of top/bottom');

  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return Positioned(
      top: top,
      bottom: top == null ? (bottom ?? 48) : null,
      left: 14,
      right: 14,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          label: 'Limited map mode — showing a low-detail offline map',
          child: Material(
            color: semantic.warningContainer,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.signal_wifi_off,
                    size: 14,
                    color: semantic.onWarningContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Limited map (offline)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: semantic.onWarningContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
