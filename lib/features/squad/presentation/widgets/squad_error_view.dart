import 'package:flutter/material.dart';

import 'squad_page_shared.dart';

/// Reserved for a genuine failure of the underlying squad stream (see
/// `SquadCubit._subscribeToMySquad`'s doc comment) — a failed create/join no
/// longer routes here, so both real recovery paths stay available instead of
/// only the one the user happened not to be using.
class SquadErrorView extends StatelessWidget {
  const SquadErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => showCreateSquadDialog(context),
                  child: const Text('Create a squad'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => showJoinSquadDialog(context),
                  child: const Text('Join with code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
