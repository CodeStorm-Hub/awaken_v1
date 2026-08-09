import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../profile/domain/repositories/auth_repository.dart';
import '../../../../core/theme/shape_tokens.dart';

class QuickActionsPill extends StatelessWidget {
  const QuickActionsPill({
    super.key,
    required this.onOpenTerritory,
    required this.onOpenSquad,
  });

  final VoidCallback onOpenTerritory;
  final VoidCallback onOpenSquad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = getIt<AuthRepository>().currentUser;
    final isGuest = user == null || user.isAnonymous;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: ShapeTokens.r12),
            ),
            onPressed: onOpenTerritory,
            icon: Icon(
              isGuest ? Icons.lock_outline : Icons.directions_run,
              size: 18,
            ),
            label: Text(
              isGuest ? 'Unlock Run' : 'Start run',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outline, width: 0.5),
              backgroundColor: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: ShapeTokens.r12),
            ),
            onPressed: onOpenSquad,
            icon: Icon(isGuest ? Icons.lock_outline : Icons.groups, size: 18),
            label: Text(
              isGuest ? 'Unlock Squad' : 'Squad',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
