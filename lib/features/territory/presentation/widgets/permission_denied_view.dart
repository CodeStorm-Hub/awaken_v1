import 'package:flutter/material.dart';

class PermissionDeniedView extends StatelessWidget {
  const PermissionDeniedView({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Location access is needed to track a run.',
              style: TextStyle(color: scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
