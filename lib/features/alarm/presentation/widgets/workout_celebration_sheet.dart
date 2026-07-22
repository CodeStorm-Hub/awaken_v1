import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/alarm_schedule.dart';
import '../../domain/usecases/watch_current_streak.dart';

/// The "hero moment" after a verified dismissal (plan §6 Phase 4 / Claude
/// Design handoff "CelebrationSheet").
class WorkoutCelebrationSheet extends StatelessWidget {
  const WorkoutCelebrationSheet({required this.alarm, required this.repsCompleted, super.key});

  final AlarmSchedule alarm;
  final int repsCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            ExpressiveFlower(
              size: 116,
              color: scheme.primaryContainer,
              animatePop: true,
              child: Icon(Icons.emoji_events, size: 52, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 18),
            Text(
              'Alarm dismissed!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Nice work — that's how mornings are won.",
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            StreamBuilder<int>(
              stream: getIt<WatchCurrentStreak>()(),
              builder: (context, snapshot) {
                final streak = snapshot.data ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        bg: scheme.secondaryContainer,
                        fg: scheme.onSecondaryContainer,
                        radius: const BorderRadius.horizontal(
                          left: Radius.circular(20),
                          right: Radius.circular(8),
                        ),
                        value: '$repsCompleted',
                        label: _exerciseNoun(alarm.exerciseMode),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _StatChip(
                        bg: scheme.tertiaryContainer,
                        fg: scheme.onTertiaryContainer,
                        radius: const BorderRadius.horizontal(
                          left: Radius.circular(8),
                          right: Radius.circular(20),
                        ),
                        icon: Icons.local_fire_department,
                        value: '$streak',
                        label: 'day streak',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nice!'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _exerciseNoun(ExerciseMode mode) => switch (mode) {
    ExerciseMode.squat => 'squats',
    ExerciseMode.pushup => 'push-ups',
  };
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.bg,
    required this.fg,
    required this.radius,
    required this.value,
    required this.label,
    this.icon,
  });

  final Color bg;
  final Color fg;
  final BorderRadius radius;
  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 24, color: fg), const SizedBox(width: 4)],
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
