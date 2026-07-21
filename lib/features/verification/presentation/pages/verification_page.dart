import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../data/datasources/camera_datasource.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/entities/verification_state.dart';
import '../bloc/verification_cubit.dart';
import '../widgets/skeleton_painter.dart';

/// Camera + pose verification screen (plan §6 Phase 2). Standalone for now
/// — wiring this in as the alarm-dismiss gate (instead of `AlarmRingPage`'s
/// direct dismiss button) is Phase 4 (see the TODO in `alarm_ring_page.dart`).
class VerificationPage extends StatelessWidget {
  const VerificationPage({required this.exercise, required this.targetReps, super.key});

  final ExerciseMode exercise;
  final int targetReps;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerificationCubit>(
      create: (_) => getIt<VerificationCubit>()..begin(exercise: exercise, targetReps: targetReps),
      child: const _VerificationView(),
    );
  }
}

class _VerificationView extends StatelessWidget {
  const _VerificationView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<VerificationCubit, VerificationState>(
        builder: (context, state) {
          return switch (state.status) {
            VerificationStatus.permissionDenied => const _PermissionDeniedView(),
            VerificationStatus.initializing => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            _ => _CameraView(state: state),
          };
        },
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView({required this.state});

  final VerificationState state;

  @override
  Widget build(BuildContext context) {
    final controller = getIt<CameraDataSource>().controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // Camera frames come in landscape sensor orientation; portrait preview
    // swaps width/height (see SkeletonPainter's imageSize doc comment).
    final previewSize = controller.value.previewSize;
    final imageSize = previewSize == null
        ? Size.zero
        : Size(previewSize.height, previewSize.width);

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform(
          alignment: Alignment.center,
          // Mirror the front-camera preview to match what the user expects
          // to see (a "mirror", not a flipped selfie).
          transform: Matrix4.rotationY(3.14159),
          child: CameraPreview(controller),
        ),
        CustomPaint(painter: SkeletonPainter(pose: state.currentPose, imageSize: imageSize)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _StatusBanner(state: state),
                const Spacer(),
                _RepCounter(state: state),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final VerificationState state;

  @override
  Widget build(BuildContext context) {
    final message = switch (state.status) {
      VerificationStatus.noPoseDetected =>
        "Can't see you clearly — step back or find better light.",
      VerificationStatus.calibrating =>
        'Do ${state.calibrationRepsRemaining} clean rep${state.calibrationRepsRemaining == 1 ? '' : 's'} to calibrate.',
      VerificationStatus.counting => 'Keep going!',
      VerificationStatus.complete => 'Nice work — alarm dismissed.',
      _ => '',
    };
    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
    );
  }
}

class _RepCounter extends StatelessWidget {
  const _RepCounter({required this.state});

  final VerificationState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${state.completedReps} / ${state.targetReps}',
          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          exerciseLabel(state.exerciseMode),
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 24),
        if (state.isComplete)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              VerificationResult(completed: true, repsCompleted: state.completedReps),
            ),
            child: const Text('Done'),
          )
        else
          // Accessibility path (plan §5 point 5): never trap a user who
          // genuinely can't perform the exercise today. Logged/streak-
          // affecting, but always escapable.
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              VerificationResult(completed: false, repsCompleted: state.completedReps),
            ),
            child: const Text(
              "I can't do this exercise today",
              style: TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Camera access is needed to verify your exercise.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                const VerificationResult(completed: false, repsCompleted: 0),
              ),
              child: const Text("I can't do this exercise today", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

String exerciseLabel(ExerciseMode mode) => switch (mode) {
  ExerciseMode.squat => 'Squats',
  ExerciseMode.pushup => 'Push-ups',
};
