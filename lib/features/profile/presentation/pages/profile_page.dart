import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/google_logo.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../alarm/presentation/pages/alarm_reliability_test_page.dart';
import '../../../onboarding/presentation/pages/battery_exemption_page.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/link_with_email.dart';
import '../../domain/usecases/link_with_google.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_in_with_password.dart';
import '../../domain/usecases/sign_out.dart';
import '../auth_error_message.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';

/// Profile screen (Claude Design handoff — `isProfile`). Streak/territory-
/// area/current-user come from the per-page `ProfileCubit` (Phase 3:
/// previously two nested `StreamBuilder`s calling use cases directly via
/// `getIt`). "Alarm reliability" and "Battery & location" route to the
/// app's real existing pages. "Migrate to cloud"/Appearance/Sign out are
/// wired to real auth/theme state (plan §6 Phase 6.5) — Notifications was
/// cut entirely rather than left as a dead tappable row, since no
/// notification-settings feature exists to back it.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocProvider<ProfileCubit>(
      create: (_) => getIt<ProfileCubit>(),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Back',
                      child: Material(
                        color: scheme.surfaceContainerHigh,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.arrow_back,
                              size: 22,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, profile) {
                    final user = profile.user;
                    final isAnonymous = user?.isAnonymous ?? true;
                    final displayName = user?.displayName;
                    final email = user?.email;
                    final avatarUrl = user?.avatarUrl;
                    final title = isAnonymous
                        ? 'Guest'
                        : (displayName ?? email ?? 'Account linked');
                    // Once we have a real name, the second line becomes
                    // "who" (their email) rather than repeating "synced" —
                    // the sync state is already implied by having an
                    // account at all.
                    //
                    // Anonymous sessions still sync to a real remote
                    // `auth.uid()` (ensureSession() signs in anonymously,
                    // not "offline") — the actual risk is losing access to
                    // that account on uninstall/new device without a
                    // linked email/Google identity, which is a different
                    // claim than "device only". Found live: this line
                    // hadn't been updated even after the sign-out dialog's
                    // equivalent copy was fixed.
                    final subtitle = isAnonymous
                        ? 'Add an email or Google to keep your progress if you switch devices'
                        : (displayName != null && email != null
                              ? email
                              : 'Progress syncs across devices');
                    final initial = isAnonymous
                        ? 'G'
                        : (displayName ?? email ?? 'A')[0].toUpperCase();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 22,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Column(
                              children: [
                                if (avatarUrl != null)
                                  ClipOval(
                                    child: Image.network(
                                      avatarUrl,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      // The provider's photo is a nice-to-have,
                                      // not load-bearing — fall back to the
                                      // initial badge rather than an error icon
                                      // if the CDN URL 404s/expires.
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _InitialAvatar(
                                                initial: initial,
                                                scheme: scheme,
                                              ),
                                      loadingBuilder:
                                          (context, child, progress) {
                                            if (progress == null) {
                                              return child;
                                            }
                                            return _InitialAvatar(
                                              initial: initial,
                                              scheme: scheme,
                                            );
                                          },
                                    ),
                                  )
                                else
                                  _InitialAvatar(
                                    initial: initial,
                                    scheme: scheme,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (isAnonymous) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => const _AuthDialog(
                                          mode: _AuthDialogMode.link,
                                        ),
                                      ),
                                      child: const Text('Migrate to cloud'),
                                    ),
                                  ),
                                  Center(
                                    child: TextButton(
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => const _AuthDialog(
                                          mode: _AuthDialogMode.signIn,
                                        ),
                                      ),
                                      child: const Text(
                                        'Already have an account? Sign in',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: StatTile(
                                  bg: scheme.primaryContainer,
                                  fg: scheme.onPrimaryContainer,
                                  value:
                                      '${(profile.ownedAreaSqm / 1000000).toStringAsFixed(2)} km²',
                                  label: 'Territory',
                                  hasError: profile.ownedAreaError,
                                  radius: const BorderRadius.horizontal(
                                    left: Radius.circular(24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: StatTile(
                                  bg: scheme.tertiaryContainer,
                                  fg: scheme.onTertiaryContainer,
                                  value: '${profile.streak}',
                                  label: 'Day streak',
                                  hasError: profile.streakError,
                                  radius: const BorderRadius.horizontal(
                                    right: Radius.circular(24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Settings',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _SettingsRow(
                            icon: Icons.bug_report,
                            label: 'Alarm reliability',
                            radius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                              bottom: Radius.circular(8),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AlarmReliabilityTestPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          _SettingsRow(
                            icon: Icons.battery_charging_full,
                            label: 'Battery & location',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const BatteryExemptionPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          _SettingsRow(
                            icon: Icons.palette,
                            label: 'Appearance',
                            radius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(20),
                            ),
                            onTap: () => _showAppearanceDialog(context),
                          ),
                          const SizedBox(height: 18),
                          // Sign out is reversible (sign back in any time); Delete
                          // account is not. Both previously used identical
                          // red-text styling with no visual cue for the
                          // difference in severity — found in design critique.
                          Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.onSurfaceVariant,
                              ),
                              onPressed: () => _showSignOutDialog(context),
                              child: const Text('Sign out'),
                            ),
                          ),
                          Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.error,
                              ),
                              onPressed: () =>
                                  _showDeleteAccountDialog(context),
                              child: const Text('Delete account'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showAppearanceDialog(BuildContext context) async {
  final cubit = context.read<ThemeModeCubit>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return BlocBuilder<ThemeModeCubit, ThemeMode>(
        bloc: cubit,
        builder: (context, current) {
          return SimpleDialog(
            title: const Text('Appearance'),
            children: [
              RadioGroup<ThemeMode>(
                groupValue: current,
                onChanged: (value) {
                  if (value != null) cubit.setThemeMode(value);
                  Navigator.of(dialogContext).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        title: Text(switch (mode) {
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                          ThemeMode.system => 'System default',
                        }),
                        value: mode,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showSignOutDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'This clears your data from this device. If you linked an email or Google account, '
        "it's still safe in the cloud — sign back in any time to get it back.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await getIt<SignOut>()(const NoParams());
  }
}

Future<void> _showDeleteAccountDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text(
        'This permanently deletes your account and all cloud-synced data — alarms, sessions, '
        'runs, territories, and squad membership. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await getIt<DeleteAccount>()(const NoParams());
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthErrorMessage(e))));
    }
  }
}

enum _AuthDialogMode { link, signIn }

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// One dialog, two modes: linking an anonymous session to email/password
/// (the "sign-up" equivalent) or signing in as a returning linked user —
/// the flow that was previously missing entirely, leaving anyone who lost
/// their local session with no way back into their own account. Rebuilt as
/// a StatefulWidget (the old version was a stateless closure) specifically
/// to support inline loading/error state and a submit-lock, since the old
/// dialog closed itself before its async call even resolved.
class _AuthDialog extends StatefulWidget {
  const _AuthDialog({required this.mode});

  final _AuthDialogMode mode;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  late var _mode = widget.mode;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_mode == _AuthDialogMode.link) {
        await getIt<LinkWithEmail>()(email: email, password: password);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
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
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Signed in.')));
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
      if (_mode == _AuthDialogMode.link) {
        await getIt<LinkWithGoogle>()(const NoParams());
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account linked with Google.')),
          );
        }
      } else {
        await getIt<SignInWithGoogle>()(const NoParams());
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
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
    final isLink = _mode == _AuthDialogMode.link;
    return AlertDialog(
      title: Text(isLink ? 'Migrate to cloud' : 'Sign in'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
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
                          ? _AuthDialogMode.signIn
                          : _AuthDialogMode.link;
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
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// The letter-badge fallback shown when there's no provider photo (every
/// email/password account, and anonymous/loading/error states for linked
/// ones).
class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initial, required this.scheme});

  final String initial;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ExpressiveFlower(
      size: 84,
      color: scheme.secondaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
