import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/gamification_widgets.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../alarm/presentation/pages/alarm_reliability_test_page.dart';
import '../../../onboarding/presentation/pages/battery_exemption_page.dart';
import '../../../squad/domain/entities/streak_tier.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';
import '../widgets/account_actions_section.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/edit_name_dialog.dart';
import '../widgets/initial_avatar.dart';
import '../widgets/settings_row.dart';

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
                                                    InitialAvatar(
                                                      initial: initial,
                                                      scheme: scheme,
                                                    ),
                                            loadingBuilder:
                                                (context, child, progress) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return InitialAvatar(
                                                    initial: initial,
                                                    scheme: scheme,
                                                  );
                                                },
                                          ),
                                        )
                                      : InitialAvatar(
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
                                          onTap: () => showEditNameDialog(
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
                                      onPressed: () => AuthDialog.show(
                                        context,
                                        mode: AuthDialogMode.link,
                                      ),
                                      child: const Text('Save progress to cloud'),
                                    ),
                                  ),
                                  Center(
                                    child: TextButton(
                                      onPressed: () => AuthDialog.show(
                                        context,
                                        mode: AuthDialogMode.signIn,
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
                                SettingsRow(
                                  icon: Icons.bug_report_outlined,
                                  label: 'Alarm reliability',
                                  isFirst: true,
                                  onTap: () =>
                                      AlarmReliabilityTestPage.push(context),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 52,
                                  color: scheme.outline,
                                ),
                                SettingsRow(
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
                                SettingsRow(
                                  icon: Icons.palette_outlined,
                                  label: 'Appearance',
                                  onTap: () => _showAppearanceDialog(context),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 52,
                                  color: scheme.outline,
                                ),
                                SettingsRow(
                                  icon: Icons.privacy_tip_outlined,
                                  label: 'Privacy Policy',
                                  onTap: () => _openLegalUrl(
                                    context,
                                    AppConstants.privacyPolicyUrl,
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 52,
                                  color: scheme.outline,
                                ),
                                SettingsRow(
                                  icon: Icons.gavel_outlined,
                                  label: 'Terms & Conditions',
                                  isLast: true,
                                  onTap: () => _openLegalUrl(
                                    context,
                                    AppConstants.termsAndConditionsUrl,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AccountActionsSection(displayName: displayName),
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

Future<void> _openLegalUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the link.')),
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
