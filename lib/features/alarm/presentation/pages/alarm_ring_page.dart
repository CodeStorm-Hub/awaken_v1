import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/navigator_key.dart';
import '../../../../core/theme/expressive_widgets.dart';
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
  late DateTime _now;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

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
    if (result == null) {
      // `||` short-circuits, so `!mounted` must guard setState directly —
      // checking it only as part of this condition still let setState fire
      // unconditionally whenever `result == null`/`!result.completed` was
      // true, even after the ring page had already been disposed (e.g. the
      // native alarm's own ring cycle ended while verification was up).
      if (mounted) setState(() => _workoutStarted = false);
      return;
    }

    await cubit.completeWorkout(
      widget.alarm,
      verified: result.completed,
      repsCompleted: result.repsCompleted,
    );
    if (!result.completed) {
      if (mounted) setState(() => _workoutStarted = false);
      return;
    }
    if (!mounted) return;

    final navContext = navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      await showModalBottomSheet<void>(
        context: navContext,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
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
    final scheme = Theme.of(context).colorScheme;
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false, // back button must not silently dismiss the alarm
      child: Scaffold(
        backgroundColor: scheme.errorContainer,
        body: SafeArea(
          child: Stack(
            // Stack defaults to StackFit.loose — without `expand`, the
            // non-positioned Padding/Column below shrink-wraps to its
            // content's width and renders off-center instead of filling
            // (centering) across the full screen.
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onErrorContainer.withValues(alpha: 0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RingingBell(scheme: scheme),
                    const SizedBox(height: 28),
                    Text(
                      widget.alarm.exerciseMode == ExerciseMode.squat
                          ? 'Time to squat!'
                          : 'Time to push up!',
                      style: TextStyle(
                        fontSize: 30,
                        height: 36 / 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                        color: scheme.onErrorContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '$effectiveReps',
                      style: TextStyle(
                        fontSize: 84,
                        height: 88 / 84,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -3,
                        color: scheme.onErrorContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'reps to dismiss',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onErrorContainer.withValues(alpha: 0.85),
                      ),
                    ),
                    if (taxMultiplier > 1.0) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: scheme.error,
                        child: Text(
                          'Wake-up tax applied (×${taxMultiplier.toStringAsFixed(1)})',
                          style: TextStyle(
                            color: scheme.onError,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 8,
                child: _StartWorkoutButton(
                  scheme: scheme,
                  onPressed: () => _startWorkout(context, effectiveReps),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingingBell extends StatefulWidget {
  const _RingingBell({required this.scheme});

  final ColorScheme scheme;

  @override
  State<_RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<_RingingBell> with TickerProviderStateMixin {
  late final AnimationController _controller;
  // Handoff's `m3x-wiggle`: -8deg..8deg, 0.5s ease-in-out infinite — a
  // 250ms repeat(reverse: true) cycle covers exactly that 0.5s round trip.
  late final AnimationController _wiggleController;
  late final Animation<double> _wiggle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _wiggleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
      ..repeat(reverse: true);
    _wiggle = Tween<double>(begin: -8 * (3.14159 / 180), end: 8 * (3.14159 / 180)).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    return SizedBox(
      width: 128,
      height: 128,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _ringAt(_controller.value, scheme.error),
              _ringAt((_controller.value + 0.5) % 1.0, scheme.error),
              child!,
            ],
          );
        },
        child: ExpressiveFlower(
          size: 128,
          color: scheme.error,
          child: AnimatedBuilder(
            animation: _wiggle,
            builder: (context, child) => Transform.rotate(angle: _wiggle.value, child: child),
            child: Icon(Icons.alarm, size: 52, color: scheme.onError),
          ),
        ),
      ),
    );
  }

  Widget _ringAt(double t, Color color) {
    final scale = 1.0 + t * 0.5;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3)),
        ),
      ),
    );
  }
}

class _StartWorkoutButton extends StatefulWidget {
  const _StartWorkoutButton({required this.scheme, required this.onPressed});

  final ColorScheme scheme;
  final VoidCallback onPressed;

  @override
  State<_StartWorkoutButton> createState() => _StartWorkoutButtonState();
}

class _StartWorkoutButtonState extends State<_StartWorkoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    return Semantics(
      button: true,
      label: 'Start workout to dismiss',
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        height: 64,
        decoration: BoxDecoration(
          color: scheme.onErrorContainer,
          borderRadius: BorderRadius.circular(_pressed ? 24 : 999),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam, size: 24, color: scheme.errorContainer),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Start workout to dismiss',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.errorContainer,
                  ),
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
