import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

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
  State<AlarmReliabilityTestPage> createState() => _AlarmReliabilityTestPageState();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Alarm reliability self-test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This schedules a test alarm ${_testDelay.inSeconds} seconds from '
              'now, with a 1-rep squat requirement. For a real test of OEM '
              'battery killers, start it, then LOCK YOUR SCREEN and, '
              'ideally, swipe Awaken away from the recent-apps list. The '
              'alarm should still fire.',
            ),
            const SizedBox(height: 24),
            _buildStatus(),
            const Spacer(),
            FilledButton(
              onPressed: _phase == _TestPhase.waiting ? null : () => _startTest(cubit),
              child: Text(_phase == _TestPhase.waiting ? 'Test running…' : 'Start test'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    switch (_phase) {
      case _TestPhase.idle:
        return const Text('Not started.');
      case _TestPhase.waiting:
        return Text('Waiting for alarm scheduled at ${_scheduledFor!.toLocal()}…');
      case _TestPhase.passed:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('PASS — fired ${_measuredDelay!.inSeconds}s after scheduling.'),
          ],
        );
      case _TestPhase.timedOut:
        return const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'FAIL — alarm did not fire within the expected window. Check '
                'battery-exemption settings and OEM autostart permissions.',
              ),
            ),
          ],
        );
    }
  }
}
