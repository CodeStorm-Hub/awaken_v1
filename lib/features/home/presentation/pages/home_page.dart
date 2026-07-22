import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../../alarm/domain/usecases/watch_current_streak.dart';
import '../../../alarm/presentation/bloc/alarm_cubit.dart';
import '../../../alarm/presentation/bloc/alarm_state.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../squad/domain/entities/squad.dart';
import '../../../squad/domain/usecases/watch_my_rank.dart';
import '../../../squad/domain/usecases/watch_my_squad.dart';
import '../../../territory/domain/usecases/watch_owned_area.dart';
import '../../domain/entities/recent_activity_entry.dart';
import '../../domain/usecases/watch_recent_activity.dart';

const _weekdayAbbrLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Home dashboard (Claude Design handoff — `isHome`). Next-alarm, streak,
/// territory area, squad rank, achievements, and the activity feed are all
/// real now (`AlarmCubit`, `WatchCurrentStreak`, `WatchOwnedArea`,
/// `WatchMyRank`/`WatchMySquad`, `WatchRecentActivity` — plan §6 Phases 5c/
/// 6). "Today's goal" remains the design prototype's placeholder — there's
/// still no daily-goal domain concept.
class HomePage extends StatelessWidget {
  const HomePage({required this.onOpenAlarms, required this.onOpenTerritory, required this.onOpenSquad, super.key});

  final VoidCallback onOpenAlarms;
  final VoidCallback onOpenTerritory;
  final VoidCallback onOpenSquad;

  AlarmSchedule? _nextAlarm(List<AlarmSchedule> alarms) {
    if (alarms.isEmpty) return null;
    final sorted = [...alarms]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return sorted.first;
  }

  String _recurrenceSuffix(Set<int> recurringDays) {
    if (recurringDays.isEmpty) return '';
    if (recurringDays.length == 7) return ' · Every day';
    final sorted = recurringDays.toList()..sort();
    return ' · ${sorted.map((d) => _weekdayAbbrLabels[d - 1]).join(', ')}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: BlocBuilder<AlarmCubit, AlarmState>(
          builder: (context, state) {
            final nextAlarm = _nextAlarm(state.alarms);
            final nextAlarmLabel = nextAlarm == null
                ? '--:--'
                : '${nextAlarm.scheduledTime.hour.toString().padLeft(2, '0')}:'
                      '${nextAlarm.scheduledTime.minute.toString().padLeft(2, '0')}';
            final nextAlarmSubtitle = nextAlarm == null
                ? 'No alarms scheduled'
                : '${nextAlarm.exerciseMode == ExerciseMode.squat ? 'Squats' : 'Push-ups'} · '
                      '${nextAlarm.requiredReps} reps'
                      '${_recurrenceSuffix(nextAlarm.recurringDays)}';

            return StreamBuilder<int>(
              stream: getIt<WatchCurrentStreak>()(),
              builder: (context, streakSnapshot) {
                final streak = streakSnapshot.data ?? 0;
                const goalPct = 70; // no daily-goal domain concept yet — placeholder, matches handoff mock

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                              ),
                              Text(
                                'Awaken',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: scheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.local_fire_department, size: 17, color: scheme.onTertiaryContainer),
                                    const SizedBox(width: 5),
                                    Text(
                                      '$streak',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ProfileAvatar(
                                onTap: () => Navigator.of(
                                  context,
                                ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NextAlarmCard(
                              label: nextAlarmLabel,
                              subtitle: nextAlarmSubtitle,
                              onViewAlarms: onOpenAlarms,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: StatTile(
                                    bg: scheme.tertiaryContainer,
                                    fg: scheme.onTertiaryContainer,
                                    icon: Icons.local_fire_department,
                                    value: '$streak',
                                    label: 'Day streak',
                                    radius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: StreamBuilder<double>(
                                    stream: getIt<WatchOwnedArea>()(),
                                    builder: (context, ownedAreaSnapshot) {
                                      final areaSqm = ownedAreaSnapshot.data ?? 0;
                                      return StatTile(
                                        bg: scheme.secondaryContainer,
                                        fg: scheme.onSecondaryContainer,
                                        icon: Icons.landscape,
                                        value: (areaSqm / 1000000).toStringAsFixed(2),
                                        label: 'km² owned',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: StreamBuilder<int?>(
                                    stream: getIt<WatchMyRank>()(),
                                    builder: (context, rankSnapshot) {
                                      final rank = rankSnapshot.data;
                                      return StatTile(
                                        bg: scheme.surfaceContainerHigh,
                                        fg: scheme.onSurface,
                                        icon: Icons.emoji_events,
                                        value: rank == null ? '—' : '#$rank',
                                        label: 'Squad rank',
                                        radius: const BorderRadius.horizontal(right: Radius.circular(24)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Material(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(24),
                              elevation: 2,
                              shadowColor: scheme.shadow,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: goalPct / 100,
                                            strokeWidth: 6,
                                            strokeCap: StrokeCap.round,
                                            color: scheme.primary,
                                            // The unfilled track needs real
                                            // contrast against this card's own
                                            // surfaceContainerHigh background —
                                            // surfaceContainer was a near-
                                            // identical tone (remaining 30% was
                                            // invisible), and outlineVariant
                                            // only measures ~1.4:1 here, well
                                            // under WCAG 1.4.11's 3:1 for a
                                            // functional progress track.
                                            backgroundColor: scheme.outline,
                                          ),
                                          Text(
                                            '$goalPct%',
                                            style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Today's goal",
                                            style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                                          ),
                                          Text(
                                            '14 / 20 squats completed',
                                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Achievements',
                              style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                            ),
                            const SizedBox(height: 12),
                            _AchievementsRow(streak: streak),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickAction(
                                    bg: scheme.secondaryContainer,
                                    fg: scheme.onSecondaryContainer,
                                    icon: Icons.directions_run,
                                    label: 'Start run',
                                    radius: const BorderRadius.horizontal(left: Radius.circular(999)),
                                    onTap: onOpenTerritory,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: _QuickAction(
                                    bg: scheme.surfaceContainerHighest,
                                    fg: scheme.onSurface,
                                    // surfaceContainerHigh was nearly the same
                                    // tone as the page's own surface, so this
                                    // button all but disappeared. `outline`
                                    // (not `outlineVariant`, ~1.6:1 here) gets
                                    // this to WCAG 1.4.11's 3:1 for a
                                    // functional button boundary.
                                    border: Border.all(color: scheme.outline),
                                    icon: Icons.groups,
                                    label: 'View squad',
                                    radius: const BorderRadius.horizontal(right: Radius.circular(999)),
                                    onTap: onOpenSquad,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Recent activity',
                              style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                            ),
                            const SizedBox(height: 10),
                            const _RecentActivitySection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Profile',
      child: Material(
        color: scheme.secondaryContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                'G',
                style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Real unlock state (previously a hardcoded mock list contradicting the
/// adjacent real "Day streak"/squad stats — found in a live UI review).
class _AchievementsRow extends StatelessWidget {
  const _AchievementsRow({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: getIt<WatchOwnedArea>()(),
      builder: (context, areaSnapshot) {
        final areaSqm = areaSnapshot.data ?? 0;
        return StreamBuilder<Squad?>(
          stream: getIt<WatchMySquad>()(),
          builder: (context, squadSnapshot) {
            final scheme = Theme.of(context).colorScheme;
            final achievements = [
              (icon: Icons.local_fire_department, label: '4-day streak', unlocked: streak >= 4),
              (icon: Icons.landscape, label: 'First territory', unlocked: areaSqm > 0),
              (icon: Icons.groups, label: 'Squad player', unlocked: squadSnapshot.data != null),
              (icon: Icons.emoji_events, label: '30-day streak', unlocked: streak >= 30),
            ];
            return Row(
              children: achievements.map((a) {
                return Expanded(
                  child: Column(
                    children: [
                      ExpressiveFlower(
                        size: 58,
                        color: a.unlocked ? scheme.tertiaryContainer : scheme.surfaceContainerHigh,
                        child: Icon(
                          a.icon,
                          size: 26,
                          color: a.unlocked ? scheme.onTertiaryContainer : scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        a.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

/// Real activity feed sourced from local `sessions`/`runs` (previously a
/// hardcoded mock list, including a "Joined Squad" entry with no backing
/// event data — found in a live UI review). Squad-join isn't modeled here
/// since nothing tracks a join timestamp yet.
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<RecentActivityEntry>>(
      stream: getIt<WatchRecentActivity>()(),
      builder: (context, snapshot) {
        final activity = snapshot.data ?? const [];
        if (activity.isEmpty) {
          return Text(
            'No activity yet — dismiss an alarm or capture territory to see it here.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          );
        }
        return Column(
          children: List.generate(activity.length, (i) {
            final a = activity[i];
            final icon = a.kind == RecentActivityKind.alarmDismissed ? Icons.check_circle : Icons.landscape;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: groupedItemRadius(index: i, count: activity.length, outer: 18),
                elevation: 1,
                shadowColor: scheme.shadow,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 19, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(a.text, style: TextStyle(fontSize: 14, color: scheme.onSurface)),
                      ),
                      Text(
                        _relativeTime(a.occurredAt),
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _NextAlarmCard extends StatelessWidget {
  const _NextAlarmCard({required this.label, required this.subtitle, required this.onViewAlarms});

  final String label;
  final String subtitle;
  final VoidCallback onViewAlarms;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm, size: 17, color: scheme.onPrimaryContainer.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                'Next alarm',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 60,
              height: 64 / 60,
              fontWeight: FontWeight.w800,
              letterSpacing: -2.5,
              color: scheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimaryContainer,
                  foregroundColor: scheme.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: onViewAlarms,
                child: const Text('View alarms'),
              ),
              const SizedBox(width: 8),
              Material(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onViewAlarms,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.add, size: 22, color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.label,
    required this.radius,
    required this.onTap,
    this.border,
  });

  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
  final BorderRadius radius;
  final VoidCallback onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: radius, border: border),
      child: Material(
        color: bg,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
