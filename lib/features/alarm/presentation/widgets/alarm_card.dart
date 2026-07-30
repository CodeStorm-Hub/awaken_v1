import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/alarm_schedule.dart';
import 'alarm_chip.dart';
import 'weekday_labels.dart';

class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.on,
    required this.radius,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  final AlarmSchedule alarm;
  final bool on;
  final BorderRadius radius;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  String get _timeLabel =>
      '${alarm.scheduledTime.hour.toString().padLeft(2, '0')}:'
      '${alarm.scheduledTime.minute.toString().padLeft(2, '0')}';

  String get _recurrenceLabel {
    final days = alarm.recurringDays;
    if (days.isEmpty) return 'One-time';
    if (days.length == 7) return 'Every day';
    final sorted = days.toList()..sort();
    return sorted.map((d) => weekdayLabels[d - 1]).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = on ? scheme.surfaceContainer : scheme.surfaceContainerHigh;
    final chipBg = on
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surfaceContainer;
    final chipFg = on ? scheme.primary : scheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(
          color: on
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.15),
          width: on ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label:
                      '$_timeLabel, ${alarm.requiredReps} '
                      '${alarm.exerciseMode == ExerciseMode.squat ? 'squats' : 'push-ups'}, '
                      '$_recurrenceLabel, alarm ${on ? 'on' : 'off'}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timeLabel,
                          style: TextStyle(
                            fontSize: 44,
                            height: 48 / 44,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                            color: on
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AlarmChip(
                              bg: chipBg,
                              fg: chipFg,
                              icon: alarm.exerciseMode == ExerciseMode.squat
                                  ? Icons.accessibility_new
                                  : Icons.sports_gymnastics,
                              label:
                                  '${alarm.requiredReps} ${alarm.exerciseMode == ExerciseMode.squat ? 'squats' : 'push-ups'}',
                            ),
                            AlarmChip(
                              bg: chipBg,
                              fg: chipFg,
                              label: _recurrenceLabel,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ExpressiveSwitch(value: on, onChanged: (_) => onToggle()),
                    const SizedBox(height: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      // Tinted with the error role instead of the same
                      // neutral `fg` as the rest of the card — a delete
                      // action should read as destructive before the
                      // confirmation dialog even opens, not blend in with
                      // the rest of the card's icons.
                      color: scheme.error,
                      onPressed: onDelete,
                      tooltip: 'Delete alarm',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
