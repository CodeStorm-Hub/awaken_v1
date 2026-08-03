import 'package:flutter/material.dart';

import '../squad_error_message.dart';

/// Shared dialog shape for create-squad/join-squad/report-member — a
/// disposed `TextEditingController`, a submit lock so a failed or slow
/// network call can't be double-fired, inline validation, and an inline
/// error message on failure instead of the dialog vanishing with only a
/// SnackBar (or, previously for create/join, the whole page falling back to
/// a generic error screen — see `SquadErrorView`'s doc comment).
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.submitLabel,
    required this.onSubmit,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final String title;
  final String hintText;
  final String submitLabel;
  final Future<void> Function(String value) onSubmit;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  State<TextPromptDialog> createState() => TextPromptDialogState();
}

class TextPromptDialogState extends State<TextPromptDialog> {
  final _controller = TextEditingController();
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'This field is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(value);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlySquadErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            maxLines: widget.maxLines,
            textCapitalization: widget.textCapitalization,
            decoration: InputDecoration(hintText: widget.hintText),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
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
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
