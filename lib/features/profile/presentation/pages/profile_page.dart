import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../alarm/domain/usecases/watch_current_streak.dart';
import '../../../alarm/presentation/pages/alarm_reliability_test_page.dart';
import '../../../onboarding/presentation/pages/battery_exemption_page.dart';

/// Profile screen (Claude Design handoff — `isProfile`). Streak is real
/// (`WatchCurrentStreak`); territory area has no domain layer yet
/// (placeholder, same caveat as `TerritoryPage`). "Alarm reliability" and
/// "Battery & location" route to the app's real existing pages;
/// Notifications/Appearance/Sign out are inert, matching the design
/// prototype's own `onClick: () => {}` no-ops for those rows.
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
                        Container(
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
                                  'G',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Guest',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: scheme.onSurface),
                              ),
                              Text(
                                'Progress is saved on this device only',
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                                onPressed: () {},
                                child: const Text('Migrate to cloud'),
                              ),
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
                                value: '0.21 km²',
                                label: 'Territory',
                                radius: const BorderRadius.horizontal(left: Radius.circular(24)),
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
                          icon: Icons.notifications,
                          label: 'Notifications',
                          radius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(8)),
                          onTap: () {},
                        ),
                        const SizedBox(height: 3),
                        _SettingsRow(
                          icon: Icons.bug_report,
                          label: 'Alarm reliability',
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
                          onTap: () {},
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: scheme.error),
                            onPressed: () {},
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
