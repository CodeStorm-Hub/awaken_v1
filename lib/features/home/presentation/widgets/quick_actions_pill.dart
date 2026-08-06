import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    bool isGuest = false;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      isGuest = user == null || user.isAnonymous;
    } catch (_) {
      isGuest = false;
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenTerritory,
            icon: Icon(isGuest ? Icons.lock_outline : Icons.directions_run, size: 18),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
