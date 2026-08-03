import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../sync/outbox/sync_worker.dart';
import '../../../../sync/sync_status.dart';
import '../../domain/entities/rival.dart';
import '../../domain/entities/territory_at_risk.dart';
import '../../domain/usecases/watch_owned_area.dart';
import '../pages/active_run_page.dart';

/// HUD chrome for `TerritoryPage`'s map overlay — extracted verbatim (no
/// behavior change) from `territory_page.dart`, which had grown past 2700
/// lines. Every widget here is a small, self-contained `StatelessWidget`
/// with no dependency on `_TerritoryPageState`'s map-controller/layer
/// bookkeeping, making this the safe first cut of that file to split out.

/// Surfaces `SyncWorker.status` — previously defined but never consumed by
/// any UI, so a stuck/failed sync (e.g. a captured run stuck in the local
/// outbox, never reaching the server) was completely invisible to the user.
/// Hidden on `idle` (nothing pending); `error` gets a manual retry button
/// rather than silently waiting on the next backoff/periodic drain.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<SyncStatus>(
      stream: getIt<SyncWorker>().status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || status == SyncStatus.idle) {
          return const SizedBox.shrink();
        }

        final (icon, label, bg, fg) = switch (status) {
          SyncStatus.syncing => (
            null,
            'Syncing…',
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
          ),
          SyncStatus.offline => (
            Icons.cloud_off,
            "Offline — will sync when you're back online",
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
          ),
          SyncStatus.error => (
            Icons.sync_problem,
            "Couldn't sync some changes",
            scheme.errorContainer,
            scheme.onErrorContainer,
          ),
          SyncStatus.idle => (null, '', scheme.surface, scheme.onSurface),
        };

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppleGlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderRadius: BorderRadius.circular(999),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == SyncStatus.syncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else
                  Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label, style: TextStyle(fontSize: 12, color: fg)),
                ),
                if (status == SyncStatus.error) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => unawaited(getIt<SyncWorker>().drainOutbox()),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class OwnedAreaChip extends StatelessWidget {
  const OwnedAreaChip({super.key, required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: getIt<WatchOwnedArea>()(),
      builder: (context, snapshot) {
        final areaSqm = snapshot.data ?? 0;
        final label = '${(areaSqm / 1000000).toStringAsFixed(3)} km²';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield, size: 13, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TerritoryLegend extends StatelessWidget {
  const TerritoryLegend({super.key, required this.showRivalTerritory});

  final bool showRivalTerritory;

  @override
  Widget build(BuildContext context) {
    // Single source of truth (item 2): reads the same
    // `context.semanticColors` roles the map's own fill/outline redraw
    // logic uses in `_TerritoryPageState._redrawFills`, instead of a
    // second, independently-hardcoded set of hex literals.
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LegendDot(color: semantic.territoryOwned),
          const SizedBox(width: 6),
          Text(
            'YOU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: scheme.onSurface,
            ),
          ),
          if (showRivalTerritory) ...[
            const SizedBox(width: 12),
            // Dashed ring around the dot (rather than a plain solid dot)
            // mirrors the map's own dashed-outline cue for rival territory
            // (item 3) — colorblind users get the same secondary shape
            // signal in the legend as on the map itself.
            LegendDot(color: semantic.territoryRival, dashed: true),
            const SizedBox(width: 6),
            Text(
              'RIVALS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: scheme.onSurface,
              ),
            ),
          ],
          const SizedBox(width: 12),
          LegendDot(color: semantic.territoryNeutral, hollow: true),
          const SizedBox(width: 6),
          Text(
            'OPEN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Altitude-gated HUD chip (Conquest Skyline redesign §6) — appears once
/// the camera is both tilted (`_is3D`) and zoomed past the city-buildings
/// layer's `minzoom: 14` (see `TerritoryMapStyle.applyCityBuildings`), so
/// crossing into "you can see the skyline now" reads as a deliberate
/// game-state change rather than just a camera angle.
class SkylineModeChip extends StatelessWidget {
  const SkylineModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_city, size: 12, color: scheme.tertiary),
          const SizedBox(width: 4),
          Text(
            'SKYLINE MODE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: scheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class AtRiskBanner extends StatelessWidget {
  const AtRiskBanner({super.key, required this.territories, required this.scheme});

  final List<TerritoryAtRisk> territories;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final soonest = territories.reduce(
      (a, b) => a.expiresAt.isBefore(b.expiresAt) ? a : b,
    );
    final remaining = soonest.expiresAt.difference(DateTime.now());
    // Under 24h previously still read `.inDays` -> "0d", the most urgent
    // case reading as the least informative. Switch to hours below a day.
    final timeLeft = remaining.inDays >= 1
        ? '${remaining.inDays.clamp(0, 99)}d'
        : '${remaining.inHours.clamp(0, 23)}h';
    final label = territories.length == 1
        ? "1 territory undefended — reverts in $timeLeft"
        : "${territories.length} territories undefended — reverts in $timeLeft";
    // Same role the map's own pulsing at-risk border uses (item 5/2) —
    // this banner and the map polygon it's describing now share one color
    // source instead of two independently chosen "warning orange" hexes.
    final atRiskColor = context.semanticColors.territoryAtRisk;

    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      borderColor: atRiskColor.withValues(alpha: 0.6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: atRiskColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DEFEND TERRITORY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: atRiskColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RivalCard extends StatelessWidget {
  const RivalCard({super.key, required this.rival, required this.scheme});

  final Rival rival;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final name = rival.rivalDisplayName ?? 'A rival';
    final areaLabel =
        '${(rival.areaTakenSqm / 1000000).toStringAsFixed(3)} km²';
    final isWinner = rival.asWinner;
    final accentColor = isWinner
        ? scheme.primary
        : context.semanticColors.territoryRival;
    final label = isWinner
        ? 'Captured $areaLabel from $name'
        : '$name seized $areaLabel from you';

    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      borderColor: accentColor.withValues(alpha: 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWinner ? Icons.emoji_events : Icons.sports_mma,
              size: 16,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isWinner ? 'VICTORY' : 'RIVAL ATTACK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: accentColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Only shown when the rival took land from the caller — a win
          // already reads as resolved and doesn't need a follow-up CTA.
          // `current_rival()` now carries the rival's territory centroid
          // (`Rival.territoryLat`/`territoryLng`, null if they currently own
          // no territory), so this opens `ActiveRunPage` focused there
          // instead of the default zoomed-out world view.
          if (!isWinner) ...[
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ActiveRunPage(
                    focusLocation: rival.territoryLat != null
                        ? LatLng(rival.territoryLat!, rival.territoryLng!)
                        : null,
                  ),
                ),
              ),
              child: const Text('Steal back'),
            ),
          ],
        ],
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  const LegendDot({
    super.key,
    required this.color,
    this.dashed = false,
    this.hollow = false,
  });

  final Color color;

  /// Ring instead of a filled dot, with a dashed-looking border — mirrors
  /// the map's dashed rival outline (item 3) as a shape cue, not just hue.
  final bool dashed;

  /// Outline-only, no fill — mirrors the neutral-zone ring style (item 4).
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    if (dashed || hollow) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: dashed ? 2 : 1.5),
        ),
      );
    }
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
            ),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.scheme,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final ColorScheme scheme;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return AppleGlassContainer(
      borderRadius: BorderRadius.circular(999),
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundIconButton(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onTap: onZoomIn,
          ),
          Container(
            width: 24,
            height: 0.5,
            color: scheme.outline.withValues(alpha: 0.3),
          ),
          RoundIconButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onTap: onZoomOut,
          ),
        ],
      ),
    );
  }
}
