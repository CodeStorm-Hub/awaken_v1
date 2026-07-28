import 'dart:async';

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
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: AppleGlassContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _GreetingText(),
                                  Text(
                                    'Awaken',
                                    style: TextStyle(
                                      fontSize: 22,
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
                                    // A hard `height:` forces the child Row
                                    // into that exact cross-axis size — at
                                    // large system text scale the Text
                                    // below needs more than 30dp and
                                    // overflows (`RenderFlex`) instead of
                                    // the pill growing. `constraints` with
                                    // only a minimum lets it grow.
                                    constraints: const BoxConstraints(
                                      minHeight: 30,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFF9F0A,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.local_fire_department,
                                          size: 14,
                                          color: Color(0xFFFF9F0A),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${home.streak}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFF9F0A),
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
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _NextAlarmCard(
                                label: nextAlarmLabel,
                                subtitle: nextAlarmSubtitle,
                                onViewAlarms: onOpenAlarms,
                              ),
                              const SizedBox(height: 12),
                              if (home.streak == 0 && home.ownedAreaSqm == 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    "Dismiss an alarm or capture territory to build your stats.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryLabelColor(context),
                                    ),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.surfaceContainer,
                                      fg: scheme.primary,
                                      icon: Icons.local_fire_department,
                                      value: '${home.streak}',
                                      label: 'Day streak',
                                      hasError: home.streakError,
                                      radius: const BorderRadius.horizontal(
                                        left: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.surfaceContainer,
                                      fg: const Color(0xFFFF9F0A),
                                      icon: Icons.landscape,
                                      value: (home.ownedAreaSqm / 1000000)
                                          .toStringAsFixed(2),
                                      label: 'km² owned',
                                      hasError: home.ownedAreaError,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: StatTile(
                                      bg: scheme.surfaceContainer,
                                      fg: const Color(0xFF30D158),
                                      icon: Icons.emoji_events,
                                      value: home.squadRank == null
                                          ? '—'
                                          : '#${home.squadRank}',
                                      label: 'Squad rank',
                                      hasError: home.squadRankError,
                                      radius: const BorderRadius.horizontal(
                                        right: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _QuickActionsPill(
                                onOpenTerritory: onOpenTerritory,
                                onOpenSquad: onOpenSquad,
                              ),
                              const SizedBox(height: 14),
                              const _SectionLabel('ACHIEVEMENTS'),
                              _AchievementsRow(
                                streak: home.streak,
                                ownedAreaSqm: home.ownedAreaSqm,
                                hasSquad: home.squad != null,
                              ),
                              const SizedBox(height: 14),
                              const _SectionLabel('RECENT ACTIVITY'),
                              _RecentActivitySection(
                                activity: home.recentActivity,
                                hasError: home.recentActivityError,
                                onRetry: () => context
                                    .read<HomeCubit>()
                                    .retryRecentActivity(),
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
        label: '4d Streak',
        unlocked: streak >= 4,
      ),
      (icon: Icons.landscape, label: 'Territory', unlocked: ownedAreaSqm > 0),
      (icon: Icons.groups, label: 'Squad', unlocked: hasSquad),
      (icon: Icons.emoji_events, label: '30d Streak', unlocked: streak >= 30),
    ];
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: achievements.map((a) {
          return Semantics(
            label: '${a.label}, ${a.unlocked ? 'unlocked' : 'locked'}',
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: a.unlocked
                          ? scheme.primary.withValues(alpha: 0.2)
                          : scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      a.icon,
                      size: 18,
                      color: a.unlocked
                          ? scheme.primary
                          : secondaryLabelColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: a.unlocked
                          ? scheme.onSurface
                          : secondaryLabelColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.activity,
    required this.hasError,
    required this.onRetry,
  });

  final List<RecentActivityEntry> activity;
  final bool hasError;
  final VoidCallback onRetry;

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
      return Row(
        children: [
          Expanded(
            child: Text(
              "Couldn't load recent activity.",
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      );
    }
    if (activity.isEmpty) {
      return Text(
        'No activity yet — dismiss an alarm or capture territory.',
        style: TextStyle(fontSize: 12, color: secondaryLabelColor(context)),
      );
    }
    return Column(
      children: List.generate(activity.length, (i) {
        final a = activity[i];
        final icon = a.kind == RecentActivityKind.alarmDismissed
            ? Icons.check_circle_outline
            : Icons.landscape_outlined;
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: AppleGlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderRadius: groupedItemRadius(
              index: i,
              count: activity.length,
              outer: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  _relativeTime(a.occurredAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryLabelColor(context),
                  ),
                ),
              ],
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
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.alarm, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'NEXT ALARM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryLabelColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary.withValues(alpha: 0.18),
              foregroundColor: scheme.primary,
              elevation: 0,
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: onViewAlarms,
            child: const Text(
              'Alarms',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

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
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenTerritory,
            icon: const Icon(Icons.directions_run, size: 18),
            label: const Text(
              'Start run',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outline, width: 0.5),
              backgroundColor: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenSquad,
            icon: const Icon(Icons.groups, size: 18),
            label: const Text(
              'Squad',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Previously computed once per `HomePage.build()` and never re-evaluated —
/// a user who opened the app just before a morning/afternoon/evening
/// rollover and left it foregrounded (this tab stays mounted via the shell's
/// `IndexedStack`) would keep seeing the stale greeting indefinitely. Ticks
/// on a coarse timer rather than depending on some other rebuild happening
/// to occur near the rollover.
/// The small uppercase section header ("ACHIEVEMENTS", "RECENT ACTIVITY")
/// — extracted since its color depends on `context` (`secondaryLabelColor`),
/// so it's no longer expressible as a top-level `const` literal the way it
/// was before, and this keeps that at one definition instead of two.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: secondaryLabelColor(context),
        ),
      ),
    );
  }
}

class _GreetingText extends StatefulWidget {
  const _GreetingText();

  @override
  State<_GreetingText> createState() => _GreetingTextState();
}

class _GreetingTextState extends State<_GreetingText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _greeting,
      style: TextStyle(fontSize: 11, color: secondaryLabelColor(context)),
    );
  }
}
