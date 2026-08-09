import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/adaptive_dialog.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../data/datasources/camera_datasource.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/entities/verification_state.dart';
import '../bloc/verification_cubit.dart';
import '../widgets/skeleton_painter.dart';
import '../../../../core/theme/shape_tokens.dart';

/// Camera + pose verification screen (plan §6 Phase 2). Wired in as the
/// alarm-dismiss gate — `AlarmRingPage` pushes this instead of exposing any
/// direct dismiss path (Phase 4, shipped; see `AlarmRingPage`'s class doc).
class VerificationPage extends StatelessWidget {
  const VerificationPage({
    required this.exercise,
    required this.targetReps,
    super.key,
  });

  final ExerciseMode exercise;
  final int targetReps;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerificationCubit>(
      create: (_) =>
          getIt<VerificationCubit>()
            ..begin(exercise: exercise, targetReps: targetReps),
      child: const _VerificationView(),
    );
  }
}

class _VerificationView extends StatefulWidget {
  const _VerificationView();

  @override
  State<_VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<_VerificationView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<VerificationCubit>();
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(cubit.pause());
      case AppLifecycleState.resumed:
        unawaited(cubit.resume());
      case AppLifecycleState.detached:
        // The engine is tearing down — release ML Kit's native detector
        // here rather than never, since there's no other reliable teardown
        // hook for a process-lifetime singleton (see
        // PoseDetectorDataSource.close()).
        unawaited(cubit.releaseNativeResources());
    }
  }

  /// Previously a bare system back left with no `PopScope` at all — the
  /// route still popped (with a `null` result, silently treated the same
  /// as "I can't do this exercise today" by `alarm_ring_page.dart`), but
  /// with zero indication of what just happened, and mid-progress reps
  /// were discarded with no confirmation the way every other explicit exit
  /// point in this flow is unguarded-but-obvious (a dedicated button, not
  /// an OS gesture). Only confirms when there's actual progress to lose.
  Future<void> _handleBack(BuildContext context) async {
    final cubit = context.read<VerificationCubit>();
    final state = cubit.state;
    if (state.completedReps > 0 && !state.isComplete) {
      final confirmed = await showAdaptiveConfirmDialog(
        context: context,
        title: 'Exit workout?',
        message:
            "You've completed ${state.completedReps} of "
            '${state.targetReps} reps — leaving now won\'t dismiss the '
            'alarm.',
        cancelLabel: 'Keep going',
        confirmLabel: 'Exit',
      );
      if (!confirmed) return;
    }
    if (context.mounted) {
      Navigator.of(context).pop(
        VerificationResult(
          completed: false,
          repsCompleted: state.completedReps,
          repTrace: state.repTrace,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Scoped to `_ViewKind`, not raw `VerificationStatus` — the camera
        // view covers 5 distinct statuses (calibrating/noPoseDetected/
        // counting/complete) that change on essentially every processed
        // frame during a real session. Rebuilding on every status change
        // used to rebuild `_CameraView` — and with it `CameraPreview`, its
        // `Transform` wrapper, and the whole overlay subtree — on every
        // single rep-counter update. Since `_CameraView` no longer takes
        // `state` as a prop (each piece that needs live state now reads it
        // itself via its own narrowly-scoped `BlocBuilder`, see below),
        // building it once per camera-view entry is enough; nothing forces
        // the camera texture to rebuild for the rest of the session.
        body: BlocBuilder<VerificationCubit, VerificationState>(
          buildWhen: (previous, current) =>
              _viewKindOf(previous.status) != _viewKindOf(current.status),
          builder: (context, state) {
            return switch (_viewKindOf(state.status)) {
              _ViewKind.permissionDenied => const _PermissionDeniedView(),
              _ViewKind.cameraError => const _CameraErrorView(),
              _ViewKind.initializing => const _InitializingView(),
              _ViewKind.camera => const _CameraView(),
            };
          },
        ),
      ),
    );
  }
}

enum _ViewKind { permissionDenied, cameraError, initializing, camera }

_ViewKind _viewKindOf(VerificationStatus status) => switch (status) {
  VerificationStatus.permissionDenied => _ViewKind.permissionDenied,
  VerificationStatus.cameraError => _ViewKind.cameraError,
  VerificationStatus.initializing => _ViewKind.initializing,
  _ => _ViewKind.camera,
};

class _InitializingView extends StatelessWidget {
  const _InitializingView();

  @override
  Widget build(BuildContext context) {
    // Never a bare indefinite spinner (plan §5 point 5) — a stuck
    // initialization (camera taking unusually long, or silently hanging on
    // some device/OS combination) still needs an escape hatch, same as
    // every other state in this flow.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                const VerificationResult(completed: false, repsCompleted: 0),
              ),
              child: const Text(
                "I can't do this exercise today",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView();

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
              "Couldn't start the camera. It may be in use by another app.",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<VerificationCubit>().retry(),
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                const VerificationResult(completed: false, repsCompleted: 0),
              ),
              child: const Text(
                "I can't do this exercise today",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView();

  @override
  Widget build(BuildContext context) {
    final controller = getIt<CameraDataSource>().controller;
    if (controller == null || !controller.value.isInitialized) {
      // Shouldn't be reachable in the steady state — `PoseVerificationRepositoryImpl.start`
      // only emits the `calibrating` status (the trigger for this view's
      // `_ViewKind`) once `_camera.startFrontCameraStream` has already
      // awaited `controller.initialize()`, so by the time this rebuilds the
      // controller should already be ready. Kept as a defensive branch
      // rather than an assert, with the same escape hatch every other
      // state in this flow has — a `StatelessWidget` reading a plugin
      // singleton once at build time has no way to rebuild itself if that
      // assumption is ever violated, and a silent unrecoverable spinner
      // while a real alarm is ringing is the worst version of that failure.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  const VerificationResult(completed: false, repsCompleted: 0),
                ),
                child: const Text(
                  "I can't do this exercise today",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Camera frames come in landscape sensor orientation; portrait preview
    // swaps width/height (see SkeletonPainter's imageSize doc comment).
    final previewSize = controller.value.previewSize;
    final imageSize = previewSize == null
        ? Size.zero
        : Size(previewSize.height, previewSize.width);

    // This widget is now built exactly once per camera-view entry (see the
    // `buildWhen` on the `BlocBuilder` in `_VerificationViewState` above) —
    // none of the fields it reads here depend on `VerificationState`, only
    // on the (already-initialized, stable) camera controller. Every piece
    // below that *does* need live state reads it itself via its own
    // narrowly-scoped `BlocBuilder`, instead of this whole subtree
    // (camera texture included) rebuilding on every processed frame like
    // it used to.
    return Stack(
      fit: StackFit.expand,
      children: [
        // `RepaintBoundary` isolates the camera texture's compositing layer
        // from the overlay widgets below, which repaint far more often
        // (the skeleton painter tracks essentially every processed frame).
        RepaintBoundary(
          child: Transform(
            alignment: Alignment.center,
            // Mirror the front-camera preview to match what the user
            // expects to see (a "mirror", not a flipped selfie).
            transform: Matrix4.rotationY(3.14159),
            child: CameraPreview(controller),
          ),
        ),
        RepaintBoundary(
          child: BlocBuilder<VerificationCubit, VerificationState>(
            // No `buildWhen` — this is the one piece expected to track
            // every processed frame's pose, and it's a cheap `CustomPaint`
            // rebuild, not the whole camera subtree.
            builder: (context, state) => CustomPaint(
              painter: SkeletonPainter(
                pose: state.currentPose,
                imageSize: imageSize,
              ),
            ),
          ),
        ),
        const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Center(child: _StatusBanner()),
                _RepSegments(),
                Spacer(),
                _RepCounter(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatefulWidget {
  const _StatusBanner();

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  var _startedAnimating = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Reduce motion" — the recording-indicator pulse is decorative; the
    // dot itself (and the status text beside it) still communicates state
    // without the animation.
    //
    // `MediaQuery.disableAnimationsOf` can't be called from `initState` —
    // same crash and fix as `_RingingBellState` in `alarm_ring_page.dart`;
    // see that doc comment for the full explanation.
    if (!_startedAnimating && !MediaQuery.disableAnimationsOf(context)) {
      _startedAnimating = true;
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VerificationCubit, VerificationState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.calibrationRepsRemaining != current.calibrationRepsRemaining,
      builder: (context, state) => _buildBanner(context, state),
    );
  }

  Widget _buildBanner(BuildContext context, VerificationState state) {
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
    //
    // `liveRegion: true` (WCAG 4.1.3) — this banner's text changes
    // repeatedly through a session (low-light warning ↔ calibrating ↔
    // "Keep going!" ↔ complete) with no focus change to draw a screen
    // reader's attention to it; without this, none of those updates were
    // ever announced.
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 40,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.54),
            // Was `circular(999)` (a true pill) — the low-light guidance
            // message ("Can't see you clearly — step back or find better
            // light.") is long enough to wrap to two lines on narrower
            // phones, and a two-line pill with fully-rounded ends looks
            // broken (near-circular caps squeezing the wrapped text).
            // A smaller rounded-rect radius still reads as a soft banner
            // chip on the single-line messages and doesn't visually break
            // when the text wraps.
            borderRadius: ShapeTokens.r18,
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5449),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepSegments extends StatelessWidget {
  const _RepSegments();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VerificationCubit, VerificationState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.completedReps != current.completedReps ||
          previous.targetReps != current.targetReps,
      builder: (context, state) {
        // Previously an `if` in the parent decided whether to show this
        // section (and its leading spacer) at all — folded in here now
        // that the parent no longer holds `state` to make that call.
        final visible =
            state.targetReps > 0 &&
            state.status != VerificationStatus.calibrating &&
            state.status != VerificationStatus.initializing &&
            state.status != VerificationStatus.permissionDenied;
        if (!visible) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        // Above ~20 reps (the wake-up tax multiplies the schedule sheet's
        // already-up-to-100 rep count further) one segment per rep collapses
        // into sub-pixel slivers that convey nothing. Bucket into at most
        // `_maxSegments` segments instead — each covering a proportional
        // rep range, filled once `completedReps` clears that range's
        // threshold. For `targetReps <= _maxSegments` this reduces to
        // exactly the original one-segment-per-rep behavior.
        const maxSegments = 20;
        final segmentCount = state.targetReps < maxSegments
            ? state.targetReps
            : maxSegments;
        final repsPerSegment = state.targetReps / segmentCount;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: List.generate(segmentCount, (i) {
              final segmentThreshold = ((i + 1) * repsPerSegment).ceil();
              final filled = state.completedReps >= segmentThreshold;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == segmentCount - 1 ? 0 : 3,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 5,
                    decoration: BoxDecoration(
                      color: filled
                          ? scheme.primaryContainer
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: ShapeTokens.pill,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _RepCounter extends StatefulWidget {
  const _RepCounter();

  @override
  State<_RepCounter> createState() => _RepCounterState();
}

class _RepCounterState extends State<_RepCounter> {
  bool _bump = false;

  void _triggerBump() {
    unawaited(HapticFeedback.lightImpact());
    setState(() => _bump = true);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _bump = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // `BlocConsumer` instead of the old `didUpdateWidget`-based rep-crossed-
    // a-threshold detection — this widget's `State` now persists across
    // rebuilds driven by a `BlocBuilder` further up rather than receiving a
    // brand-new `_RepCounter(state: ...)` instance each time, so comparing
    // `widget.state` between old/new instances no longer applies. The
    // `listener` triggers the bump animation as a side effect exactly when
    // `completedReps` increases; `builder` renders.
    return BlocConsumer<VerificationCubit, VerificationState>(
      listenWhen: (previous, current) =>
          current.completedReps > previous.completedReps,
      listener: (context, state) => _triggerBump(),
      buildWhen: (previous, current) =>
          previous.completedReps != current.completedReps ||
          previous.targetReps != current.targetReps ||
          previous.status != current.status ||
          previous.exerciseMode != current.exerciseMode,
      builder: (context, state) => _buildContent(context, state),
    );
  }

  Widget _buildContent(BuildContext context, VerificationState state) {
    final scheme = Theme.of(context).colorScheme;
    final pct = state.isComplete
        ? 1.0
        : state.targetReps == 0
        ? 0.0
        : (state.completedReps / state.targetReps).clamp(0.0, 1.0);

    // `liveRegion: true` (WCAG 4.1.3) — the rep count updates on every
    // completed rep with no focus change, so a screen-reader user had no
    // way to know a rep registered short of counting reps themselves.
    // `ExcludeSemantics` on the visual ring/digits below this Semantics
    // node avoids also announcing the raw "3" text node redundantly.
    final repCountLabel = state.isComplete
        ? 'Complete — alarm dismissed'
        : '${state.completedReps} of ${state.targetReps} ${exerciseLabel(state.exerciseMode).toLowerCase()}';
    return Column(
      children: [
        Semantics(
          liveRegion: true,
          label: repCountLabel,
          child: ExcludeSemantics(
            child: AnimatedScale(
              scale: _bump ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: SizedBox(
                width: 176,
                height: 176,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: pct,
                    color: scheme.primaryContainer,
                  ),
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
                                child: Icon(
                                  Icons.check,
                                  size: 40,
                                  color: scheme.onPrimaryContainer,
                                ),
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
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'of ${state.targetReps} ${exerciseLabel(state.exerciseMode).toLowerCase()}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
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
                shape: RoundedRectangleBorder(borderRadius: ShapeTokens.pill),
              ),
              onPressed: () => Navigator.of(context).pop(
                VerificationResult(
                  completed: true,
                  repsCompleted: state.completedReps,
                  repTrace: state.repTrace,
                ),
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
              shape: RoundedRectangleBorder(borderRadius: ShapeTokens.pill),
            ),
            onPressed: () => Navigator.of(context).pop(
              VerificationResult(
                completed: false,
                repsCompleted: state.completedReps,
                repTrace: state.repTrace,
              ),
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
            // Previously the only escape hatch was giving up on the
            // exercise entirely — if the denial was accidental (or the user
            // just didn't understand the system prompt) there was no way
            // to fix it without leaving this screen, finding the app in OS
            // settings themselves, and coming back. `openAppSettings()`
            // (permission_handler) jumps straight to Awaken's app-settings
            // page, matching the same pattern already used elsewhere in the
            // app for permission recovery.
            FilledButton(
              onPressed: () => unawaited(openAppSettings()),
              child: const Text('Open Settings'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                const VerificationResult(completed: false, repsCompleted: 0),
              ),
              child: const Text(
                "I can't do this exercise today",
                style: TextStyle(color: Colors.white70),
              ),
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
