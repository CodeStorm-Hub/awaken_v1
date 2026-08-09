import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/shape_tokens.dart';

class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: ShapeTokens.r14,
      child: Row(
        children: [
          Icon(Icons.qr_code, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite code',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryLabelColor(context),
                  ),
                ),
                Text(
                  inviteCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 2,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: Icon(Icons.copy, color: scheme.primary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
