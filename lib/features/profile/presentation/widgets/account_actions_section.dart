import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/adaptive_dialog.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/sign_out.dart';
import '../auth_error_message.dart';
import 'delete_account_dialog.dart';

/// Sign-out and delete-account both sit here, deliberately separated from
/// the settings list above by their own spacing/divider/section so delete
/// reads as materially more consequential before the user ever taps it —
/// previously the two were stacked peer `TextButton`s differentiated only
/// by color. Each button owns an in-flight boolean (`_signingOut`/
/// `_deleting`) so the async sign-out/delete-account calls show a spinner
/// and disable the trigger instead of leaving the UI silently unresponsive
/// mid-request; the boolean only resets on failure (success either closes
/// this page or the state becomes moot).
class AccountActionsSection extends StatefulWidget {
  const AccountActionsSection({super.key, required this.displayName});

  final String? displayName;

  @override
  State<AccountActionsSection> createState() => _AccountActionsSectionState();
}

class _AccountActionsSectionState extends State<AccountActionsSection> {
  var _signingOut = false;
  var _deleting = false;

  Future<void> _signOut() async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Sign out?',
      message:
          'This clears your data from this device. If you linked an email or Google account, '
          "it's still safe in the cloud — sign back in any time to get it back.",
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await getIt<SignOut>()(const NoParams());
      // No app-level auth-state listener redirects on its own (the root
      // widget always shows `AppShellPage` regardless of auth state — see
      // `app.dart`); `ProfilePage` was pushed on top, so pop it back so the
      // user isn't left staring at their own now-signed-out profile page.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => _signingOut = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyAuthErrorMessage(e))));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteAccountDialog(displayName: widget.displayName),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await getIt<DeleteAccount>()(const NoParams());
      if (mounted) {
        // Same reasoning as sign-out above: nothing redirects automatically,
        // so pop back to the signed-out root explicitly rather than
        // stranding the user on a stale Profile page for a deleted account.
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account deleted.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyAuthErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: secondaryLabelColor(context),
            ),
            onPressed: _signingOut ? null : _signOut,
            child: _signingOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Divider(color: scheme.outline),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _deleting ? null : _deleteAccount,
            icon: _deleting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.error,
                    ),
                  )
                : Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: scheme.error,
                  ),
            label: const Text('Delete account'),
          ),
        ),
      ],
    );
  }
}
