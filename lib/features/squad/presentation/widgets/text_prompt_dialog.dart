import 'package:flutter/material.dart';

import '../../../../core/theme/submitting_form_dialog.dart';
import '../squad_error_message.dart';

/// Squad's flavor of [SubmittingFormDialog] — create-squad/join-squad/
/// report-member all go through this so the error mapping is squad-specific
/// while the dialog mechanics (submit lock, inline error) stay shared.
class TextPromptDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SubmittingFormDialog(
      title: title,
      hintText: hintText,
      submitLabel: submitLabel,
      onSubmit: onSubmit,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      errorMapper: friendlySquadErrorMessage,
    );
  }
}
