import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/submitting_form_dialog.dart';
import '../../domain/usecases/update_display_name.dart';
import '../auth_error_message.dart';

/// Profile-completion entry point for accounts (typically email/password
/// sign-ups from before signing up asked for a name) stuck with the
/// generated "Runner-XXXXXXXX" placeholder. Built on [SubmittingFormDialog]
/// — an earlier version of this dialog owned its own top-level
/// `TextEditingController` outside any widget's lifecycle and crashed live
/// (`ChangeNotifier.addListener` on an already-disposed notifier, cascading
/// into a `_dependents.isEmpty` assertion). Keep the controller inside the
/// shared dialog's `State`, disposed in `State.dispose`, as every other
/// dialog in this codebase does.
Future<void> showEditNameDialog(
  BuildContext context, {
  required String currentName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => SubmittingFormDialog(
      title: 'Edit name',
      labelText: 'Your name',
      submitLabel: 'Save',
      initialValue: currentName,
      emptyErrorText: 'Enter your name.',
      textCapitalization: TextCapitalization.words,
      onSubmit: (name) => getIt<UpdateDisplayName>()(name),
      errorMapper: friendlyAuthErrorMessage,
    ),
  );
}
