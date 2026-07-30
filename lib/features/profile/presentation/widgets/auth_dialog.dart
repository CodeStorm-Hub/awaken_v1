import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/google_logo.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/link_with_email.dart';
import '../../domain/usecases/link_with_google.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_in_with_password.dart';
import '../auth_error_message.dart';

enum AuthDialogMode { link, signIn }

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// One dialog, two modes: linking an anonymous session to email/password
/// (the "sign-up" equivalent) or signing in as a returning linked user —
/// the flow that was previously missing entirely, leaving anyone who lost
/// their local session with no way back into their own account. Rebuilt as
/// a StatefulWidget (the old version was a stateless closure) specifically
/// to support inline loading/error state and a submit-lock, since the old
/// dialog closed itself before its async call even resolved.
class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key, required this.mode});

  final AuthDialogMode mode;

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  late var _mode = widget.mode;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Enter your name.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_mode == AuthDialogMode.link) {
        await getIt<LinkWithEmail>()(
          email: email,
          password: password,
          displayName: name,
        );
        if (mounted) {
          // Captured before `pop()` — `ScaffoldMessenger.of(context)` after
          // popping this dialog's own context can resolve against an
          // element that's no longer in the tree for that frame.
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Check your email to confirm linking your account.',
              ),
            ),
          );
        }
      } else {
        await getIt<SignInWithPassword>()(email: email, password: password);
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          messenger.showSnackBar(const SnackBar(content: Text('Signed in.')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_mode == AuthDialogMode.link) {
        await getIt<LinkWithGoogle>()(const NoParams());
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Account linked with Google.')),
          );
        }
      } else {
        await getIt<SignInWithGoogle>()(const NoParams());
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Signed in with Google.')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      setState(
        () => _error =
            'Enter your email above first, then tap "Forgot password?".',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await getIt<SendPasswordResetEmail>()(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLink = _mode == AuthDialogMode.link;
    return AlertDialog(
      title: Text(isLink ? 'Migrate to cloud' : 'Sign in'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLink) ...[
                TextFormField(
                  controller: _nameController,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: _validateName,
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _emailController,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _validateEmail,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                enabled: !_submitting,
                obscureText: _obscurePassword,
                autofillHints: [
                  isLink ? AutofillHints.newPassword : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validatePassword,
                onFieldSubmitted: (_) => _submitEmail(),
              ),
              if (!isLink) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _submitting ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ] else
                const SizedBox(height: 8),
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submitEmail,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLink ? 'Continue with email' : 'Sign in'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const GoogleLogo(size: 18),
                  onPressed: _submitting ? null : _submitGoogle,
                  label: Text(
                    isLink ? 'Continue with Google' : 'Sign in with Google',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        _mode = isLink
                            ? AuthDialogMode.signIn
                            : AuthDialogMode.link;
                        _error = null;
                      }),
                child: Text(
                  isLink
                      ? 'Already have an account? Sign in'
                      : "Don't have an account? Migrate to cloud",
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
