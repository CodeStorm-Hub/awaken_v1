import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../alarm/domain/usecases/watch_current_streak.dart';
import '../../../alarm/presentation/pages/alarm_reliability_test_page.dart';
import '../../../onboarding/presentation/pages/battery_exemption_page.dart';
import '../../../territory/domain/usecases/watch_owned_area.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/link_with_email.dart';
import '../../domain/usecases/link_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/watch_current_user.dart';

/// Profile screen (Claude Design handoff — `isProfile`). Streak and
/// territory area are real (`WatchCurrentStreak`, `WatchOwnedArea` — plan
/// §6 Phase 5c). "Alarm reliability" and "Battery & location" route to the
/// app's real existing pages. "Migrate to cloud"/Appearance/Sign out are
/// wired to real auth/theme state (plan §6 Phase 6.5) — Notifications was
/// cut entirely rather than left as a dead tappable row, since no
/// notification-settings feature exists to back it.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Material(
                    color: scheme.surfaceContainerHigh,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.arrow_back, size: 22, color: scheme.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<int>(
                stream: getIt<WatchCurrentStreak>()(),
                builder: (context, snapshot) {
                  final streak = snapshot.data ?? 0;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StreamBuilder<AppUser?>(
                          stream: getIt<WatchCurrentUser>()(),
                          builder: (context, userSnapshot) {
                            final user = userSnapshot.data;
                            final isAnonymous = user?.isAnonymous ?? true;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                children: [
                                  ExpressiveFlower(
                                    size: 84,
                                    color: scheme.secondaryContainer,
                                    child: Text(
                                      isAnonymous ? 'G' : 'A',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isAnonymous ? 'Guest' : 'Account linked',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: scheme.onSurface),
                                  ),
                                  Text(
                                    isAnonymous
                                        ? 'Progress is saved on this device only'
                                        : 'Progress syncs across devices',
                                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                  ),
                                  if (isAnonymous) ...[
                                    const SizedBox(height: 4),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                      ),
                                      onPressed: () => _showMigrateToCloudDialog(context),
                                      child: const Text('Migrate to cloud'),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder<double>(
                                stream: getIt<WatchOwnedArea>()(),
                                builder: (context, ownedAreaSnapshot) {
                                  final areaSqm = ownedAreaSnapshot.data ?? 0;
                                  return StatTile(
                                    bg: scheme.primaryContainer,
                                    fg: scheme.onPrimaryContainer,
                                    value: '${(areaSqm / 1000000).toStringAsFixed(2)} km²',
                                    label: 'Territory',
                                    radius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: StatTile(
                                bg: scheme.tertiaryContainer,
                                fg: scheme.onTertiaryContainer,
                                value: '$streak',
                                label: 'Day streak',
                                radius: const BorderRadius.horizontal(right: Radius.circular(24)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
                        const SizedBox(height: 10),
                        _SettingsRow(
                          icon: Icons.bug_report,
                          label: 'Alarm reliability',
                          radius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(8)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AlarmReliabilityTestPage()),
                          ),
                        ),
                        const SizedBox(height: 3),
                        _SettingsRow(
                          icon: Icons.battery_charging_full,
                          label: 'Battery & location',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BatteryExemptionPage()),
                          ),
                        ),
                        const SizedBox(height: 3),
                        _SettingsRow(
                          icon: Icons.palette,
                          label: 'Appearance',
                          radius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(20)),
                          onTap: () => _showAppearanceDialog(context),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: scheme.error),
                            onPressed: () => _showSignOutDialog(context),
                            child: const Text('Sign out'),
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
        "You'll lose access to your cloud-synced data on this device unless you've linked an "
        'account. Data already on this device stays put.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sign out')),
      ],
    ),
  );
  if (confirmed == true) {
    await getIt<SignOut>()(const NoParams());
  }
}

Future<void> _showMigrateToCloudDialog(BuildContext context) async {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Migrate to cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final password = passwordController.text;
                  if (email.isEmpty || password.isEmpty) return;
                  Navigator.of(dialogContext).pop();
                  try {
                    await getIt<LinkWithEmail>()(email: email, password: password);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Check your email to confirm linking your account.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Continue with email'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    await getIt<LinkWithGoogle>()(const NoParams());
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Account linked with Google.')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                label: const Text('Continue with Google'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
        ],
      );
    },
  );
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
                decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface)),
              ),
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
