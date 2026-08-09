import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/shape_tokens.dart';

/// Weekly-leaderboard-reset ceremony (2026-07-29 UI/UX audit item 11) —
/// shown once, the first time the Squad page is opened after a weekly
/// rollover, comparing the caller's last-known weekly rank against the
/// fresh one. Reuses `WorkoutCelebrationSheet`'s visual pattern (glass flower
/// icon, headline, single "done" action) so the app's celebratory moments
/// read as one consistent visual language rather than each feature
/// inventing its own.
class WeeklyRecapSheet extends StatelessWidget {
  const WeeklyRecapSheet({
    required this.currentRank,
    required this.previousRank,
    super.key,
  });

  final int currentRank;
  final int previousRank;

  int get _delta => previousRank - currentRank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final improved = _delta > 0;
    final unchanged = _delta == 0;

    final subtitle = unchanged
        ? 'Same spot as last week — hold the line.'
        : improved
        ? 'Up $_delta from last week. Keep climbing.'
        : 'Down ${-_delta} from last week — time for a comeback run.';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: ShapeTokens.pill,
                ),
              ),
              ExpressiveFlower(
                size: 116,
                color: scheme.primaryContainer,
                animatePop: true,
                child: Icon(
                  Icons.emoji_events,
                  size: 52,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'You held #$previousRank this week',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: ShapeTokens.r20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '#$currentRank',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'now, globally, this week',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: ShapeTokens.pill,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Nice!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
