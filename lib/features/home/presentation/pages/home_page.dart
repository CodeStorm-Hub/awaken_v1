import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../../alarm/presentation/bloc/alarm_cubit.dart';
import '../../../alarm/presentation/bloc/alarm_state.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../../domain/entities/recent_activity_entry.dart';
import '../bloc/home_cubit.dart';
import '../bloc/home_state.dart';

const _weekdayAbbrLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Home dashboard (Claude Design handoff — `isHome`). Next-alarm comes from
/// the app-wide `AlarmCubit`; streak/territory-area/squad-rank/squad-
/// membership/activity-feed come from the per-page `HomeCubit` (Phase 3:
/// previously four independently nested `StreamBuilder`s calling use cases
/// directly via `getIt`, including two separate subscriptions to
/// `WatchOwnedArea`). The design prototype's "Today's goal" card was
/// removed rather than kept as a fabricated placeholder — there's no
/// daily-goal domain concept to back it with real data.
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

  /// Disabled alarms are still present in `AlarmCubit.state.alarms` (greyed
  /// out in the list — see `AlarmRepositoryImpl.watchAlarms()`'s doc
  /// comment), so picking the chronologically-first entry without an
  /// `isActive` filter could surface a disabled alarm as "next" even though
  /// it will never actually ring.
  AlarmSchedule? _nextAlarm(List<AlarmSchedule> alarms) {
    final eligible = alarms.where((a) => a.isActive).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return eligible.isEmpty ? null : eligible.first;
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

    return BlocProvider<HomeCubit>(
      create: (_) => getIt<HomeCubit>(),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: BlocBuilder<AlarmCubit, AlarmState>(
            builder: (context, alarmState) {
              final nextAlarm = _nextAlarm(alarmState.alarms);
              final nextAlarmLabel = nextAlarm == null
                  ? '--:--'
                  : '${nextAlarm.scheduledTime.hour.toString().padLeft(2, '0')}:'
                        '${nextAlarm.scheduledTime.minute.toString().padLeft(2, '0')}';
              final nextAlarmSubtitle = nextAlarm == null
                  ? 'No alarms scheduled'
                  : '${nextAlarm.exerciseMode == ExerciseMode.squat ? 'Squats' : 'Push-ups'} · '
                        '${nextAlarm.requiredReps} reps'
                        '${_recurrenceSuffix(nextAlarm.recurringDays)}';

              return BlocBuilder<HomeCubit, HomeState>(
                builder: (context, home) {
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
                                        '${home.streak}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onTertiaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const CurrentUserAvatarButton(),
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
                              // A brand-new account showing raw "0"/"0.00 km²"
                              // stat tiles right next to a populated "#1" squad
                              // rank read as broken rather than "you haven't
                              // started yet" — found in design critique. Only
                              // shown for the genuinely fresh case; otherwise
                              // the tiles speak for themselves.
                              if (home.streak == 0 && home.ownedAreaSqm == 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    "You haven't started yet — dismiss an alarm or capture territory to build your stats.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.tertiaryContainer,
                                      fg: scheme.onTertiaryContainer,
                                      icon: Icons.local_fire_department,
                                      value: '${home.streak}',
                                      label: 'Day streak',
                                      hasError: home.streakError,
                                      radius: const BorderRadius.horizontal(
                                        left: Radius.circular(24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.secondaryContainer,
                                      fg: scheme.onSecondaryContainer,
                                      icon: Icons.landscape,
                                      value: (home.ownedAreaSqm / 1000000)
                                          .toStringAsFixed(2),
                                      label: 'km² owned',
                                      hasError: home.ownedAreaError,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: StatTile(
                                      // surfaceContainerHigh (tone ~92) sat only
                                      // ~6 tones below the page's own surface
                                      // (~98) with zero chroma — visually
                                      // invisible next to its chroma-bearing
                                      // siblings (tertiary/secondaryContainer),
                                      // confirmed against a live screenshot.
                                      // primaryContainer completes the
                                      // primary/secondary/tertiary triad across
                                      // the row instead of relying on lightness
                                      // alone to read as a tile.
                                      bg: scheme.primaryContainer,
                                      fg: scheme.onPrimaryContainer,
                                      icon: Icons.emoji_events,
                                      value: home.squadRank == null
                                          ? '—'
                                          : '#${home.squadRank}',
                                      label: 'Squad rank',
                                      hasError: home.squadRankError,
                                      radius: const BorderRadius.horizontal(
                                        right: Radius.circular(24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Achievements',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _AchievementsRow(
                                streak: home.streak,
                                ownedAreaSqm: home.ownedAreaSqm,
                                hasSquad: home.squad != null,
                              ),
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
                              _RecentActivitySection(
                                activity: home.recentActivity,
                                hasError: home.recentActivityError,
                              ),
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
      ),
    );
  }
}

/// Real unlock state (previously a hardcoded mock list contradicting the
/// adjacent real "Day streak"/squad stats — found in a live UI review).
class _AchievementsRow extends StatelessWidget {
  const _AchievementsRow({
    required this.streak,
    required this.ownedAreaSqm,
    required this.hasSquad,
  });

  final int streak;
  final double ownedAreaSqm;
  final bool hasSquad;

  @override
  Widget build(BuildContext context) {
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
        unlocked: ownedAreaSqm > 0,
        hint: ownedAreaSqm > 0 ? null : 'Capture territory',
      ),
      (
        icon: Icons.groups,
        label: 'Squad player',
        unlocked: hasSquad,
        hint: hasSquad ? null : 'Join a squad',
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
            // Lock state was previously color-only (tertiaryContainer vs.
            // surfaceContainerHigh) — a screen-reader user had no way to tell
            // which achievements were earned. WCAG 1.3.1.
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
                    // surfaceContainerHigh alone can render near-invisible
                    // against the page background on some dynamic-color
                    // palettes (confirmed live) — an outline keeps the
                    // locked badge's shape legible without implying
                    // "almost unlocked" the way a chroma-bearing fill would.
                    borderColor: a.unlocked ? null : scheme.outline,
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
                      style: TextStyle(fontSize: 10, color: scheme.outline),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Real activity feed sourced from local `sessions`/`runs` (previously a
/// hardcoded mock list, including a "Joined Squad" entry with no backing
/// event data — found in a live UI review). Squad-join isn't modeled here
/// since nothing tracks a join timestamp yet.
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.activity,
    required this.hasError,
  });

  final List<RecentActivityEntry> activity;
  final bool hasError;

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
    if (hasError) {
      return Text(
        "Couldn't load recent activity.",
        style: TextStyle(fontSize: 13, color: scheme.error),
      );
    }
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
                    child: Text(
                      a.text,
                      style: TextStyle(fontSize: 14, color: scheme.onSurface),
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

/// "Start run" (primary) + "Squad" (secondary shortcut) as two visually
/// distinct pills, not one split-down-the-middle segmented control.
///
/// Redesigned from an earlier single-pill version (shared outer border +
/// 1px divider, equal 50/50 width) that fixed a real Impeller border-radius
/// rendering bug but, in doing so, made two *unrelated destinations* read
/// as mutually-exclusive options in a toggle — the visual grammar of a
/// segmented control implies "pick one," not "here's the hero action plus
/// a shortcut." Flagged directly by the user against a live screenshot.
/// Fixed by giving each its own pill (own radius, own color fill) instead
/// of a shared frame — equal-width, with the color fill (primary-filled vs.
/// tonal-container) carrying the hierarchy instead of unequal sizing, per
/// user preference. "Squad" is deliberately not dropped even though the
/// bottom nav already has a Squad tab: this is a one-tap shortcut from the
/// dashboard, the nav tab is a destination: both are legitimate, common
/// mobile patterns (e.g. a card's own "View all" beside a tab bar entry).
/// No custom shadow was added even though a generic mobile-UI pass would
/// suggest one — no other pill button in this app (Squad's Create/Join,
/// Profile's Migrate-to-cloud, `_NextAlarmCard`'s View-alarms) uses a
/// shadow, and matching the app's own established flat-pill language wins
/// over a one-off treatment here.
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
    return Row(
      children: [
        Expanded(
          child: Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpenTerritory,
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_run,
                      size: 22,
                      color: scheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Start run',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpenSquad,
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups,
                      size: 20,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Squad',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
