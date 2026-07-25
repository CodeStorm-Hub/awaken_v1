import 'package:flutter/material.dart';

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
  const MapStyleRetryingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 48,
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
