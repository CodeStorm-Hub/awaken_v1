import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../../alarm/presentation/bloc/alarm_cubit.dart';
import '../../../alarm/presentation/bloc/alarm_state.dart';
import '../../../../core/theme/shape_tokens.dart';

const _weekdayAbbrLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Owns its own narrowly-scoped `BlocBuilder<AlarmCubit>` so an alarm
/// change only rebuilds this card, not the whole `HomeCubit`-driven page
/// body (see `HomePage.build`).
class NextAlarmCardBloc extends StatelessWidget {
  const NextAlarmCardBloc({super.key, required this.onViewAlarms});

  final VoidCallback onViewAlarms;

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
    return BlocBuilder<AlarmCubit, AlarmState>(
      builder: (context, alarmState) {
        final nextAlarm = _nextAlarm(alarmState.alarms);
        final label = nextAlarm == null
            ? '--:--'
            : '${nextAlarm.scheduledTime.hour.toString().padLeft(2, '0')}:'
                  '${nextAlarm.scheduledTime.minute.toString().padLeft(2, '0')}';
        final subtitle = nextAlarm == null
            ? 'No alarms scheduled'
            : '${nextAlarm.exerciseMode == ExerciseMode.squat ? 'Squats' : 'Push-ups'} · '
                  '${nextAlarm.requiredReps} reps'
                  '${_recurrenceSuffix(nextAlarm.recurringDays)}';
        return _NextAlarmCard(
          label: label,
          subtitle: subtitle,
          onViewAlarms: onViewAlarms,
        );
      },
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
      borderRadius: ShapeTokens.r14,
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
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              elevation: 0,
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: ShapeTokens.r10),
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
