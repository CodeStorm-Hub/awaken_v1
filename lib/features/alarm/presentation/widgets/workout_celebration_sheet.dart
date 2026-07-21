import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/alarm_schedule.dart';
import '../../domain/usecases/watch_current_streak.dart';

/// The "hero moment" after a verified dismissal (plan §6 Phase 4). A modest
/// scale-in rather than a full `SpringSimulation` rig — core Flutter has no
/// M3 Expressive motion system to hook into (plan C2), and a
/// `TweenAnimationBuilder` + `Curves.easeOutBack` reads close enough to the
/// plan's "significant bounce" spatial spring for a one-shot celebration.
class WorkoutCelebrationSheet extends StatelessWidget {
  const WorkoutCelebrationSheet({required this.alarm, required this.repsCompleted, super.key});

  final AlarmSchedule alarm;
  final int repsCompleted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Icon(
                Icons.emoji_events,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('Alarm dismissed!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '$repsCompleted ${_exerciseNoun(alarm.exerciseMode)} completed',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            StreamBuilder<int>(
              stream: getIt<WatchCurrentStreak>()(),
              builder: (context, snapshot) {
                final streak = snapshot.data ?? 0;
                if (streak <= 1) return const SizedBox.shrink();
                return Text(
                  '$streak-day streak',
                  style: Theme.of(context).textTheme.titleMedium,
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nice!'),
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
