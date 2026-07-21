import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/navigator_key.dart';
import '../../../verification/domain/entities/verification_result.dart';
import '../../../verification/presentation/pages/verification_page.dart';
import '../../domain/entities/alarm_schedule.dart';
import '../bloc/alarm_cubit.dart';
import '../widgets/workout_celebration_sheet.dart';

/// Full-screen ring UI, shown over the lock screen via the native FSI
/// activity flags (MainActivity.kt). Dismissal is gated by camera-verified
/// exercise reps (plan §6 Phase 4) — the raw `dismiss()` path from Phase 1
/// is no longer reachable from here.
class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({required this.alarm, super.key});

  final AlarmSchedule alarm;

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  bool _workoutStarted = false;

  Future<void> _startWorkout(BuildContext context, int effectiveReps) async {
    setState(() {
      _workoutStarted = true;
    });

    final cubit = context.read<AlarmCubit>();
    final result = await navigatorKey.currentState!.push<VerificationResult>(
      MaterialPageRoute(
        builder: (_) => VerificationPage(exercise: widget.alarm.exerciseMode, targetReps: effectiveReps),
      ),
    );
    if (result == null || !mounted) {
      setState(() {
        _workoutStarted = false;
      });
      return;
    }

    await cubit.completeWorkout(
      widget.alarm,
      verified: result.completed,
      repsCompleted: result.repsCompleted,
    );
    if (!result.completed || !mounted) {
      setState(() {
        _workoutStarted = false;
      });
      return;
    }

    final navContext = navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      await showModalBottomSheet<void>(
        context: navContext,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => WorkoutCelebrationSheet(alarm: widget.alarm, repsCompleted: result.repsCompleted),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_workoutStarted) {
      return const SizedBox.shrink();
    }

    // Wake-up tax is global/per-user, not per-alarm (plan discussion — a
    // per-alarm tax was gameable by deleting and recreating the alarm).
    final taxMultiplier = context.watch<AlarmCubit>().state.currentTaxMultiplier;
    final effectiveReps = (widget.alarm.requiredReps * taxMultiplier).round();

    return PopScope(
      canPop: false, // back button must not silently dismiss the alarm
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.alarm.exerciseMode == ExerciseMode.squat
                      ? 'Time to squat!'
                      : 'Time to push up!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '$effectiveReps reps',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                if (taxMultiplier > 1.0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Wake-up tax applied (×${taxMultiplier.toStringAsFixed(1)})',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: () => _startWorkout(context, effectiveReps),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Text('Start Workout to Dismiss'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
