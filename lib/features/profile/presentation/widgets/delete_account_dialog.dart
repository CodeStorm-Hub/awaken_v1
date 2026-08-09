import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_dialog.dart';

/// Delete-account confirmation. A single accidental tap used to be enough
/// to permanently delete the account and all cloud data — this now
/// requires typing an exact match (the user's display name, or the literal
/// word "DELETE") before the Delete button enables at all. Cancel is the
/// autofocused/visually-default action (`FilledButton.tonal`) and Delete
/// stays a plain, disabled-by-default `TextButton` so the destructive
/// action never reads as the default choice.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.displayName});

  final String? displayName;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _controller = TextEditingController();
  var _matches = false;

  String get _requiredText {
    final name = widget.displayName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'DELETE';
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text == _requiredText;
      if (matches != _matches) setState(() => _matches = matches);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog<bool>(
      title: 'Delete account?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your alarms, run history, and territory will be permanently "
            "deleted. This can't be undone.",
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'Type '),
                TextSpan(
                  text: _requiredText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' to confirm.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: false,
            decoration: InputDecoration(
              hintText: _requiredText,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        const AdaptiveDialogAction(
          label: 'Cancel',
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: 'Delete',
          value: true,
          isDestructive: true,
          enabled: _matches,
        ),
      ],
    );
  }
}
