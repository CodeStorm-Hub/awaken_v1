import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// One action in an [AdaptiveAlertDialog] — pops the dialog with [value]
/// when tapped. [isDefault] picks out the "primary"/bold action (matches
/// `CupertinoDialogAction.isDefaultAction` and renders as `FilledButton` on
/// Material); [isDestructive] renders in the platform's destructive color
/// (`CupertinoColors.destructiveRed` / `ColorScheme.error`).
class AdaptiveDialogAction<T> {
  const AdaptiveDialogAction({
    required this.label,
    required this.value,
    this.isDefault = false,
    this.isDestructive = false,
    this.enabled = true,
  });

  final String label;
  final T value;
  final bool isDefault;
  final bool isDestructive;
  final bool enabled;
}

/// Platform-adaptive replacement for `AlertDialog` — `CupertinoAlertDialog`
/// on iOS, Material `AlertDialog` on Android/other. Every confirmation
/// dialog in this app (delete-alarm, discard-run, exit-workout, sign-out,
/// leave-squad, delete-account) previously used a bare Material
/// `AlertDialog` unconditionally, even on iOS builds, despite the rest of
/// the app's iOS-tinted theming — real iOS users notice a modal that
/// doesn't match their platform's stacked-button dialog convention even
/// when colors/fonts do. [content] is an arbitrary widget (not just a
/// string) so this also covers dialogs with real interactive content, not
/// only a message (e.g. `DeleteAccountDialog`'s confirmation `TextField`).
class AdaptiveAlertDialog<T> extends StatelessWidget {
  const AdaptiveAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<AdaptiveDialogAction<T>> actions;

  /// `Platform.isIOS` (not `Theme.of(context).platform`) — deliberately
  /// reads the real OS, not a debug platform override, since this is about
  /// matching actual iOS system conventions for real iOS users, not a
  /// visual-testing toggle.
  static bool get _useCupertino => Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    if (_useCupertino) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: content,
        actions: [
          for (final action in actions)
            CupertinoDialogAction(
              isDefaultAction: action.isDefault,
              isDestructiveAction: action.isDestructive,
              onPressed: action.enabled
                  ? () => Navigator.of(context).pop(action.value)
                  : null,
              child: Text(action.label),
            ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        for (final action in actions)
          if (action.isDefault)
            FilledButton(
              onPressed: action.enabled
                  ? () => Navigator.of(context).pop(action.value)
                  : null,
              style: action.isDestructive
                  ? FilledButton.styleFrom(backgroundColor: scheme.error)
                  : null,
              child: Text(action.label),
            )
          else
            TextButton(
              onPressed: action.enabled
                  ? () => Navigator.of(context).pop(action.value)
                  : null,
              style: action.isDestructive
                  ? TextButton.styleFrom(foregroundColor: scheme.error)
                  : null,
              child: Text(action.label),
            ),
      ],
    );
  }
}

/// One selectable option in [showAdaptiveChoiceDialog].
class AdaptiveChoiceOption<T> {
  const AdaptiveChoiceOption({required this.label, required this.value});

  final String label;
  final T value;
}

/// Platform-adaptive single-choice picker (e.g. "Appearance": Light/Dark/
/// System) — `CupertinoActionSheet` on iOS (the system convention for this
/// exact shape: a short list of mutually-exclusive choices plus a
/// dedicated Cancel), a `SimpleDialog`/`RadioListTile` list on
/// Android/other. Returns the selected value, or `null` if dismissed
/// without choosing.
Future<T?> showAdaptiveChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required List<AdaptiveChoiceOption<T>> options,
  required T groupValue,
}) {
  if (Platform.isIOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop(option.value),
              // No built-in "selected" affordance on
              // `CupertinoActionSheetAction` — a leading check mirrors how
              // `RadioListTile` shows the current choice on the Material
              // side, so the current selection isn't Android-exclusive
              // information.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (option.value == groupValue) ...[
                    const Icon(CupertinoIcons.check_mark, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Text(option.label),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<T>(
          groupValue: groupValue,
          onChanged: (value) => Navigator.of(dialogContext).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                RadioListTile<T>(
                  title: Text(option.label),
                  value: option.value,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The common case — a title, a plain-text message, and a cancel/confirm
/// pair. Returns `true` only if the confirming action was tapped; `false`
/// for cancel, a barrier tap, or a system back.
Future<bool> showAdaptiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  bool barrierDismissible = true,
  Color? barrierColor,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: (dialogContext) => AdaptiveAlertDialog<bool>(
      title: title,
      content: Text(message),
      actions: [
        AdaptiveDialogAction(label: cancelLabel, value: false),
        AdaptiveDialogAction(
          label: confirmLabel,
          value: true,
          isDefault: true,
          isDestructive: isDestructive,
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
