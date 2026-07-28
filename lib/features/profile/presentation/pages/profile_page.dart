import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/gamification_widgets.dart';
import '../../../../core/theme/google_logo.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../alarm/presentation/pages/alarm_reliability_test_page.dart';
import '../../../onboarding/presentation/pages/battery_exemption_page.dart';
import '../../../squad/domain/entities/streak_tier.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/link_with_email.dart';
import '../../domain/usecases/link_with_google.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_in_with_password.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_display_name.dart';
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
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: AppleGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Back',
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            // Was 36x36 — below WCAG 2.5.5's 44x44 minimum;
                            // icon stays the same visual size.
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 16,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: scheme.onSurface,
                            ),
                      ),
                    ],
                  ),
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
                    final subtitle = isAnonymous
                        ? 'Add an email or Google to keep your progress if you switch devices'
                        : (displayName != null && email != null
                              ? email
                              : 'Progress syncs across devices');
                    final initial = avatarInitial(
                      isAnonymous: isAnonymous,
                      displayName: displayName,
                      email: email,
                    );
                    final dpr = MediaQuery.devicePixelRatioOf(context);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppleGlassContainer(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 22,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              children: [
                                StreakTierAvatarRing(
                                  tier: streakTierForDays(profile.streak),
                                  size: 96,
                                  child: avatarUrl != null
                                      ? ClipOval(
                                          child: Image.network(
                                            avatarUrl,
                                            width: 84,
                                            height: 84,
                                            fit: BoxFit.cover,
                                            cacheWidth: (84 * dpr).round(),
                                            cacheHeight: (84 * dpr).round(),
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
                                      : _InitialAvatar(
                                          initial: initial,
                                          scheme: scheme,
                                        ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(color: scheme.onSurface),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Edit name',
                                      child: Material(
                                        color: Colors.transparent,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => _showEditNameDialog(
                                            context,
                                            currentName: displayName ?? '',
                                          ),
                                          // Was ~28x28 effective — below the
                                          // 44x44 WCAG 2.5.5 minimum already
                                          // applied to the back button above.
                                          child: SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: scheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: secondaryLabelColor(context),
                                      ),
                                ),
                                if (isAnonymous) ...[
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: StatTile(
                                  bg: scheme.surfaceContainer,
                                  fg: scheme.primary,
                                  value:
                                      '${(profile.ownedAreaSqm / 1000000).toStringAsFixed(2)} km²',
                                  label: 'Territory',
                                  hasError: profile.ownedAreaError,
                                  radius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: StatTile(
                                  bg: scheme.surfaceContainer,
                                  fg: context.semanticColors.streakFlame,
                                  value: '${profile.streak}',
                                  label: 'Day streak',
                                  hasError: profile.streakError,
                                  radius: const BorderRadius.horizontal(
                                    right: Radius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'SETTINGS',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: secondaryLabelColor(context),
                                  ),
                            ),
                          ),
                          AppleGlassContainer(
                            borderRadius: BorderRadius.circular(14),
                            child: Column(
                              children: [
                                _SettingsRow(
                                  icon: Icons.bug_report_outlined,
                                  label: 'Alarm reliability',
                                  isFirst: true,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AlarmReliabilityTestPage(),
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 52,
                                  color: scheme.outline,
                                ),
                                _SettingsRow(
                                  icon: Icons.battery_charging_full,
                                  label: 'Battery & location',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BatteryExemptionPage(),
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 52,
                                  color: scheme.outline,
                                ),
                                _SettingsRow(
                                  icon: Icons.palette_outlined,
                                  label: 'Appearance',
                                  isLast: true,
                                  onTap: () => _showAppearanceDialog(context),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _AccountActionsSection(displayName: displayName),
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

/// Sign-out and delete-account both sit here, deliberately separated from
/// the settings list above by their own spacing/divider/section so delete
/// reads as materially more consequential before the user ever taps it —
/// previously the two were stacked peer `TextButton`s differentiated only
/// by color. Each button owns an in-flight boolean (`_signingOut`/
/// `_deleting`) so the async sign-out/delete-account calls show a spinner
/// and disable the trigger instead of leaving the UI silently unresponsive
/// mid-request; the boolean only resets on failure (success either closes
/// this page or the state becomes moot).
class _AccountActionsSection extends StatefulWidget {
  const _AccountActionsSection({required this.displayName});

  final String? displayName;

  @override
  State<_AccountActionsSection> createState() => _AccountActionsSectionState();
}

class _AccountActionsSectionState extends State<_AccountActionsSection> {
  var _signingOut = false;
  var _deleting = false;

  Future<void> _signOut() async {
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
    if (confirmed != true || !mounted) return;

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
      builder: (_) => _DeleteAccountDialog(displayName: widget.displayName),
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

/// Delete-account confirmation. A single accidental tap used to be enough
/// to permanently delete the account and all cloud data — this now
/// requires typing an exact match (the user's display name, or the literal
/// word "DELETE") before the Delete button enables at all. Cancel is the
/// autofocused/visually-default action (`FilledButton.tonal`) and Delete
/// stays a plain, disabled-by-default `TextButton` so the destructive
/// action never reads as the default choice.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.displayName});

  final String? displayName;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
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
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete account?'),
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
        FilledButton.tonal(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

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
Future<void> _showEditNameDialog(
  BuildContext context, {
  required String currentName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EditNameDialog(currentName: currentName),
  );
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.currentName});

  final String currentName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
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
      if (_mode == _AuthDialogMode.link) {
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
      if (_mode == _AuthDialogMode.link) {
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
    final isLink = _mode == _AuthDialogMode.link;
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
      // See `alarm_list_page.dart`'s identical fix — light theme's
      // `secondaryContainer` is nearly invisible against the page surface
      // without a border.
      borderColor: scheme.outline,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(isFirst ? 14 : 0),
      bottom: Radius.circular(isLast ? 14 : 0),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: secondaryLabelColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
