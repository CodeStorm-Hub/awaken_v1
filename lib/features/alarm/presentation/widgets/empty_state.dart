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
            SizedBox(
              width: 220,
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
