import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../territory/presentation/pages/territory_page.dart';
import 'conquest_ticker.dart';
import 'squad_page_shared.dart';
import '../../../../core/theme/shape_tokens.dart';

class NoSquadView extends StatelessWidget {
  const NoSquadView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExpressiveFlower(
              size: 84,
              color: scheme.secondaryContainer,
              // See `alarm_list_page.dart`'s identical fix — light theme's
              // `secondaryContainer` is nearly invisible against the page
              // surface without a border.
              borderColor: scheme.outline,
              child: Icon(
                Icons.groups,
                size: 36,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "You're not in a squad yet",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Create one to invite friends, or join with an invite code.',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const ConquestTicker(),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: ShapeTokens.pill),
                ),
                onPressed: () => showCreateSquadDialog(context),
                child: const Text('Create a squad'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: ShapeTokens.pill),
                ),
                onPressed: () => showJoinSquadDialog(context),
                child: const Text('Join with invite code'),
              ),
            ),
            const SizedBox(height: 20),
            // No squad yet still leaves "capture territory to appear on a
            // leaderboard" reachable — previously only the loaded-and-empty
            // squad leaderboard (below) carried this hint, so a brand new
            // user had no path from here to Territory at all.
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  // Pushed as its own route here, not a shell tab — always
                  // active for as long as this route exists, so a
                  // never-changing `true` listenable is correct (no shell
                  // tab-switching to react to).
                  builder: (_) =>
                      TerritoryPage(isActive: ValueNotifier<bool>(true)),
                ),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Capture territory to start earning a rank'),
            ),
          ],
        ),
      ),
    );
  }
}
