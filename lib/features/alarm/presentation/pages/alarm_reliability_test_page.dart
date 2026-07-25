import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/alarm_schedule.dart';
import '../bloc/alarm_cubit.dart';
import '../bloc/alarm_state.dart';

enum _TestPhase { idle, waiting, passed, timedOut }

/// Tooling for the Phase 1 exit criterion (plan §6): "alarm fires reliably
/// from killed state on real devices, screen off, 30+ min after kill."
/// This page schedules a short-delay alarm and measures whether it
/// actually fires — the instructions push the user toward the real test
/// (lock the screen, swipe the app away) rather than just leaving the app
/// open, since that's the failure mode this whole exercise exists to catch.
class AlarmReliabilityTestPage extends StatefulWidget {
  const AlarmReliabilityTestPage({super.key});

  @override
  State<AlarmReliabilityTestPage> createState() =>
      _AlarmReliabilityTestPageState();
}

class _AlarmReliabilityTestPageState extends State<AlarmReliabilityTestPage> {
  static const _testDelay = Duration(seconds: 60);
  static const _timeoutGrace = Duration(seconds: 30);

  _TestPhase _phase = _TestPhase.idle;
  String? _testAlarmId;
  DateTime? _scheduledFor;
  Duration? _measuredDelay;
  StreamSubscription<AlarmState>? _sub;
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _sub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _startTest(AlarmCubit cubit) async {
    final id = const Uuid().v4();
    final scheduledFor = DateTime.now().add(_testDelay);

    setState(() {
      _phase = _TestPhase.waiting;
      _testAlarmId = id;
      _scheduledFor = scheduledFor;
      _measuredDelay = null;
    });

    await cubit.schedule(
      AlarmSchedule(
        id: id,
        scheduledTime: scheduledFor,
        exerciseMode: ExerciseMode.squat,
        requiredReps: 1,
      ),
    );

    _sub?.cancel();
    _sub = cubit.stream.listen((state) {
      if (state.ringingAlarm?.id == _testAlarmId) {
        _timeoutTimer?.cancel();
        setState(() {
          _phase = _TestPhase.passed;
          _measuredDelay = DateTime.now().difference(_scheduledFor!);
        });
      }
    });

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_testDelay + _timeoutGrace, () {
      if (_phase == _TestPhase.waiting && mounted) {
        setState(() => _phase = _TestPhase.timedOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AlarmCubit>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Material(
                color: scheme.surfaceContainerHigh,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarm reliability self-test',
                      style: TextStyle(
                        fontSize: 30,
                        height: 36 / 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This schedules a test alarm ${_testDelay.inSeconds} seconds from '
                      'now, with a 1-rep squat requirement. For a real test of OEM '
                      'battery killers, start it, then lock your screen and, '
                      'ideally, swipe Awaken away from the recent-apps list. The '
                      'alarm should still fire.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _StatusContainer(
                      phase: _phase,
                      measuredDelay: _measuredDelay,
                      scheme: scheme,
                    ),
                    const SizedBox(height: 200),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: _phase == _TestPhase.waiting
                      ? null
                      : () => _startTest(cubit),
                  child: Text(
                    _phase == _TestPhase.waiting
                        ? 'Test running…'
                        : _phase == _TestPhase.passed ||
                              _phase == _TestPhase.timedOut
                        ? 'Run again'
                        : 'Start test',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusContainer extends StatelessWidget {
  const _StatusContainer({
    required this.phase,
    required this.measuredDelay,
    required this.scheme,
  });

  final _TestPhase phase;
  final Duration? measuredDelay;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final passed = phase == _TestPhase.passed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: passed ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          switch (phase) {
            _TestPhase.idle => Icon(
              Icons.bug_report,
              size: 36,
              color: scheme.onSurfaceVariant,
            ),
            _TestPhase.waiting => const ExpressiveLoader(),
            _TestPhase.passed => ExpressiveFlower(
              size: 72,
              color: scheme.primary,
              animatePop: true,
              child: Icon(Icons.check, size: 34, color: scheme.onPrimary),
            ),
            _TestPhase.timedOut => Icon(
              Icons.error,
              size: 36,
              color: scheme.error,
            ),
          },
          const SizedBox(height: 12),
          Text(
            switch (phase) {
              _TestPhase.idle => 'Not started.',
              _TestPhase.waiting => 'Waiting for alarm…',
              _TestPhase.passed =>
                'PASS — fired ${measuredDelay!.inSeconds}s after scheduling.',
              _TestPhase.timedOut =>
                'FAIL — alarm did not fire within the expected window. Check '
                    'battery-exemption settings and OEM autostart permissions.',
            },
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: phase == _TestPhase.passed
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: passed
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
