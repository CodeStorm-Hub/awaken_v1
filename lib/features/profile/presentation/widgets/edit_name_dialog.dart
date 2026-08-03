import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../domain/usecases/update_display_name.dart';
import '../auth_error_message.dart';

/// Profile-completion entry point for accounts (typically email/password
/// sign-ups from before signing up asked for a name) stuck with the
/// generated "Runner-XXXXXXXX" placeholder. A proper `StatefulWidget` — same
/// shape as squad_page.dart's `_TextPromptDialog` — not a top-level function
/// owning a `TextEditingController` outside any widget's lifecycle: an
/// earlier version of this dialog did exactly that (create the controller
/// in the function, dispose it manually after `showDialog` resolved) and it
/// crashed live (`ChangeNotifier.addListener` on an already-disposed
/// notifier, cascading into a `_dependents.isEmpty` assertion) — a
/// controller/`Tooltip`-driven `Listenable` outliving or racing the dialog
/// route's own element teardown. Every other dialog in this codebase avoids
/// that by keeping the controller in a `State`, disposed in `State.dispose`.
Future<void> showEditNameDialog(
  BuildContext context, {
  required String currentName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => EditNameDialog(currentName: currentName),
  );
}

class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key, required this.currentName});

  final String currentName;

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final _controller = TextEditingController(text: widget.currentName);
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await getIt<UpdateDisplayName>()(name);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlyAuthErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Your name'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
