import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';

/// The letter-badge fallback shown when there's no provider photo (every
/// email/password account, and anonymous/loading/error states for linked
/// ones).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.initial, required this.scheme});

  final String initial;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ExpressiveFlower(
      size: 84,
      color: scheme.secondaryContainer,
      // See `alarm_list_page.dart`'s identical fix — light theme's
      // `secondaryContainer` is nearly invisible against the page surface
      // without a border.
      borderColor: scheme.outline,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
