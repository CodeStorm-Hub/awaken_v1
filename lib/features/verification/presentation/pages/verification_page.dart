import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
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
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(child: _StatusBanner(state: state)),
                if (state.status != VerificationStatus.calibrating &&
                    state.status != VerificationStatus.initializing &&
                    state.status != VerificationStatus.permissionDenied) ...[
                  const SizedBox(height: 14),
                  _RepSegments(state: state),
                ],
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

class _StatusBanner extends StatefulWidget {
  const _StatusBanner({required this.state});

  final VerificationState state;

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
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

    // Longer real-app strings (e.g. the low-light message) can exceed a
    // single line at this font — the design's own mock strings are all
    // short, so the prototype never needed a max-width/wrap safety net.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!state.isComplete) ...[
              FadeTransition(
                opacity: _pulse,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFFF5449), shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepSegments extends StatelessWidget {
  const _RepSegments({required this.state});

  final VerificationState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (state.targetReps <= 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(state.targetReps, (i) {
        final filled = i < state.completedReps;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == state.targetReps - 1 ? 0 : 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 5,
              decoration: BoxDecoration(
                color: filled ? scheme.primaryContainer : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _RepCounter extends StatefulWidget {
  const _RepCounter({required this.state});

  final VerificationState state;

  @override
  State<_RepCounter> createState() => _RepCounterState();
}

class _RepCounterState extends State<_RepCounter> {
  int _lastReps = 0;
  bool _bump = false;

  @override
  void didUpdateWidget(covariant _RepCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.completedReps > _lastReps) {
      _lastReps = widget.state.completedReps;
      setState(() => _bump = true);
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _bump = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    final pct = state.isComplete
        ? 1.0
        : state.targetReps == 0
        ? 0.0
        : (state.completedReps / state.targetReps).clamp(0.0, 1.0);

    return Column(
      children: [
        AnimatedScale(
          scale: _bump ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 176,
            height: 176,
            child: CustomPaint(
              painter: _RingPainter(progress: pct, color: scheme.primaryContainer),
              child: Center(
                child: Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: state.isComplete
                        ? ExpressiveFlower(
                            size: 84,
                            color: scheme.primaryContainer,
                            animatePop: true,
                            child: Icon(Icons.check, size: 40, color: scheme.onPrimaryContainer),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${state.completedReps}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 64,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -2,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                'of ${state.targetReps} ${exerciseLabel(state.exerciseMode).toLowerCase()}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (state.isComplete)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () => Navigator.of(context).pop(
                VerificationResult(completed: true, repsCompleted: state.completedReps),
              ),
              child: const Text('Done'),
            ),
          )
        else
          // Accessibility path (plan §5 point 5): never trap a user who
          // genuinely can't perform the exercise today. Logged/streak-
          // affecting, but always escapable.
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.8),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () => Navigator.of(context).pop(
              VerificationResult(completed: false, repsCompleted: state.completedReps),
            ),
            child: const Text("I can't do this exercise today"),
          ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      true,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
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
