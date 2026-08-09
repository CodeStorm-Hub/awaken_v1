import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Column(
          children: [
            ExpressiveFlower(
              size: 108,
              color: scheme.secondaryContainer,
              // Light theme's `secondaryContainer` (`0xFFE5E5EA`) sits only
              // ~1.05:1 from the page surface (`0xFFF2F2F7`) — with no
              // border, this badge is effectively invisible in light mode
              // (see `ExpressiveFlower`'s own doc comment on `borderColor`).
              borderColor: scheme.outline,
              child: Icon(
                Icons.alarm_add,
                size: 44,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No alarms scheduled',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // Was a fixed `width: 220` — at 200%+ accessibility text scale
            // that forced many short wrapped lines in a narrow column
            // instead of reflowing to use the space actually available (the
            // parent is already `width: double.infinity`). Horizontal
            // padding alone keeps the same compact centered look at normal
            // text scale while letting large-scale text use the full width.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Schedule one and earn tomorrow morning.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
