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
  const HomePage({
    required this.onOpenAlarms,
    required this.onOpenTerritory,
    required this.onOpenSquad,
    super.key,
  });

  final VoidCallback onOpenAlarms;
  final VoidCallback onOpenTerritory;
  final VoidCallback onOpenSquad;

  AlarmSchedule? _nextAlarm(List<AlarmSchedule> alarms) {
    if (alarms.isEmpty) return null;
    final sorted = [...alarms]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
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
                const goalPct =
                    70; // no daily-goal domain concept yet — placeholder, matches handoff mock

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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      size: 17,
                                      color: scheme.onTertiaryContainer,
                                    ),
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
                              ProfileAvatarButton(
                                initial: 'G',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ProfilePage(),
                                  ),
                                ),
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
                            StreamBuilder<double>(
                              stream: getIt<WatchOwnedArea>()(),
                              builder: (context, areaHintSnapshot) {
                                final areaSqm = areaHintSnapshot.data ?? 0;
                                // A brand-new account showing raw "0"/"0.00 km²"
                                // stat tiles right next to a populated "#1"
                                // squad rank read as broken rather than
                                // "you haven't started yet" — found in design
                                // critique. Only shown for the genuinely fresh
                                // case; otherwise the tiles speak for themselves.
                                if (streak != 0 || areaSqm != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    "You haven't started yet — dismiss an alarm or capture territory to build your stats.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: StatTile(
                                    bg: scheme.tertiaryContainer,
                                    fg: scheme.onTertiaryContainer,
                                    icon: Icons.local_fire_department,
                                    value: '$streak',
                                    label: 'Day streak',
                                    radius: const BorderRadius.horizontal(
                                      left: Radius.circular(24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: StreamBuilder<double>(
                                    stream: getIt<WatchOwnedArea>()(),
                                    builder: (context, ownedAreaSnapshot) {
                                      final areaSqm =
                                          ownedAreaSnapshot.data ?? 0;
                                      return StatTile(
                                        bg: scheme.secondaryContainer,
                                        fg: scheme.onSecondaryContainer,
                                        icon: Icons.landscape,
                                        value: (areaSqm / 1000000)
                                            .toStringAsFixed(2),
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
                                        radius: const BorderRadius.horizontal(
                                          right: Radius.circular(24),
                                        ),
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
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Today's goal",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            '14 / 20 squats completed',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Achievements',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AchievementsRow(streak: streak),
                            const SizedBox(height: 22),
                            _QuickActionsPill(
                              onOpenTerritory: onOpenTerritory,
                              onOpenSquad: onOpenSquad,
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Recent activity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
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
              (
                icon: Icons.local_fire_department,
                label: '4-day streak',
                unlocked: streak >= 4,
                hint: streak >= 4
                    ? null
                    : '${4 - streak} more day${4 - streak == 1 ? '' : 's'}',
              ),
              (
                icon: Icons.landscape,
                label: 'First territory',
                unlocked: areaSqm > 0,
                hint: areaSqm > 0 ? null : 'Capture territory',
              ),
              (
                icon: Icons.groups,
                label: 'Squad player',
                unlocked: squadSnapshot.data != null,
                hint: squadSnapshot.data != null ? null : 'Join a squad',
              ),
              (
                icon: Icons.emoji_events,
                label: '30-day streak',
                unlocked: streak >= 30,
                hint: streak >= 30 ? null : '${30 - streak} more days',
              ),
            ];
            return Row(
              children: achievements.map((a) {
                return Expanded(
                  child: Semantics(
                    // Lock state was previously color-only (tertiaryContainer
                    // vs. surfaceContainerHigh) — a screen-reader user had no
                    // way to tell which achievements were earned. WCAG 1.3.1.
                    label:
                        '${a.label}, ${a.unlocked ? 'unlocked' : 'locked'}'
                        '${a.hint == null ? '' : ', ${a.hint}'}',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          ExpressiveFlower(
                            size: 58,
                            color: a.unlocked
                                ? scheme.tertiaryContainer
                                : scheme.surfaceContainerHigh,
                            child: Icon(
                              a.icon,
                              size: 26,
                              color: a.unlocked
                                  ? scheme.onTertiaryContainer
                                  : scheme.outline,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            a.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (a.hint != null)
                            Text(
                              a.hint!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
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
            final icon = a.kind == RecentActivityKind.alarmDismissed
                ? Icons.check_circle
                : Icons.landscape;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: groupedItemRadius(
                  index: i,
                  count: activity.length,
                  outer: 18,
                ),
                elevation: 1,
                shadowColor: scheme.shadow,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                        child: Text(
                          a.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(a.occurredAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
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
  const _NextAlarmCard({
    required this.label,
    required this.subtitle,
    required this.onViewAlarms,
  });

  final String label;
  final String subtitle;
  final VoidCallback onViewAlarms;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.alarm,
                size: 17,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
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
                    child: Icon(
                      Icons.add,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
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

/// Single merged pill for "Start run"/"View squad" — previously two separate
/// `Container`s, each with its own asymmetric `BorderRadius.horizontal` and
/// (for the right half) its own `Border.all()`. That combination produced a
/// stray line where the border failed to follow the curve at the seam
/// between the rounded outer corner and the square inner one (an Impeller
/// border/radius rendering quirk, found via a live-screenshot review). One
/// shared outer border + one shared radius avoids the combination entirely.
/// Also gives "Start run" the stronger filled treatment — it's the core
/// gamification-loop entry point and previously read as visually weaker
/// than "View alarms" above it for no deliberate reason.
class _QuickActionsPill extends StatelessWidget {
  const _QuickActionsPill({
    required this.onOpenTerritory,
    required this.onOpenSquad,
  });

  final VoidCallback onOpenTerritory;
  final VoidCallback onOpenSquad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: scheme.primary,
              child: InkWell(
                onTap: onOpenTerritory,
                child: SizedBox(
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_run,
                        size: 20,
                        color: scheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Start run',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, color: scheme.outline),
          Expanded(
            child: Material(
              color: scheme.surface,
              child: InkWell(
                onTap: onOpenSquad,
                child: SizedBox(
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups, size: 20, color: scheme.onSurface),
                      const SizedBox(width: 8),
                      Text(
                        'View squad',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
