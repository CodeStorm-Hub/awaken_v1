import 'package:flutter/material.dart';

/// Shared dialog shape for any single-text-field submit flow: a disposed
/// `TextEditingController`, a submit lock so a failed or slow network call
/// can't be double-fired, inline empty-value validation, and an inline error
/// message on failure instead of the dialog vanishing with only a SnackBar.
///
/// Extracted from two near-identical copies (squad's `TextPromptDialog` and
/// profile's `EditNameDialog`) that had drifted apart only in cosmetic ways
/// (hint vs. label decoration, error text style) — this is the canonical
/// version both now build on. Pops `true` on successful submit, `false`/
/// `null` on cancel or dismiss.
class SubmittingFormDialog extends StatefulWidget {
  const SubmittingFormDialog({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.initialValue = '',
    this.hintText,
    this.labelText,
    this.emptyErrorText = 'This field is required.',
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.errorMapper,
  });

  final String title;
  final String submitLabel;
  final Future<void> Function(String value) onSubmit;
  final String initialValue;
  final String? hintText;
  final String? labelText;
  final String emptyErrorText;
  final TextCapitalization textCapitalization;
  final int maxLines;

  /// Maps a thrown error to a user-facing message. Defaults to `toString()`.
  final String Function(Object error)? errorMapper;

  @override
  State<SubmittingFormDialog> createState() => _SubmittingFormDialogState();
}

class _SubmittingFormDialogState extends State<SubmittingFormDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
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
      setState(() => _error = widget.emptyErrorText);
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
          _error = widget.errorMapper?.call(e) ?? e.toString();
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
            decoration: InputDecoration(
              hintText: widget.hintText,
              labelText: widget.labelText,
            ),
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
