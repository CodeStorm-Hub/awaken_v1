import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/alarm_schedule.dart';
import 'ios_day_toggle.dart';
import 'ios_mode_pill.dart';
import 'ios_step_button.dart';
import 'weekday_labels.dart';

class ScheduleSheet extends StatefulWidget {
  const ScheduleSheet({super.key, required this.onSchedule});

  final Future<void> Function(
    ExerciseMode mode,
    int reps,
    DateTime scheduledTime,
    Set<int> days,
  )
  onSchedule;

  @override
  State<ScheduleSheet> createState() => ScheduleSheetState();
}

class ScheduleSheetState extends State<ScheduleSheet> {
  var _mode = ExerciseMode.squat;
  var _reps = 20;
  var _days = <int>{};
  var _saving = false;

  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final roundedMin = (now.minute / 5).ceil() * 5;
    _selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(Duration(minutes: roundedMin));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    // No `finally` reset on success — the sheet pops immediately after, so
    // there's no frame left where a re-enabled Save button could be tapped
    // again. On failure the sheet stays open and must re-enable it.
    try {
      await widget.onSchedule(_mode, _reps, _targetDateTime, _days);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  DateTime get _targetDateTime => AlarmSchedule.firstOccurrence(
    timeOfDay: _selectedDateTime,
    recurringDays: _days,
    from: DateTime.now(),
  );

  String _formatTargetSummary(DateTime scheduled) {
    final now = DateTime.now();
    final diff = scheduled.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    final isToday =
        scheduled.day == now.day &&
        scheduled.month == now.month &&
        scheduled.year == now.year;
    final isTomorrow =
        scheduled.difference(DateTime(now.year, now.month, now.day)).inDays ==
        1;
    final dayText = isToday
        ? 'today'
        : isTomorrow
        ? 'tomorrow'
        : weekdayFullLabels[scheduled.weekday - 1];

    final h24 = scheduled.hour;
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final amPm = h24 >= 12 ? 'PM' : 'AM';
    final minStr = scheduled.minute.toString().padLeft(2, '0');

    if (hours == 0 && minutes == 0) {
      return 'Alarm set for $dayText at $h12:$minStr $amPm (in < 1 min)';
    } else if (hours == 0) {
      return 'Alarm set for $dayText at $h12:$minStr $amPm (in $minutes mins)';
    } else {
      return 'Alarm set for $dayText at $h12:$minStr $amPm (in ${hours}h ${minutes}m)';
    }
  }

  String get _recurrenceSummary {
    if (_days.isEmpty) return 'Never';
    if (_days.length == 7) return 'Every day';
    if (_days.length == 5 && !_days.contains(6) && !_days.contains(7)) {
      return 'Weekdays';
    }
    if (_days.length == 2 && _days.contains(6) && _days.contains(7)) {
      return 'Weekends';
    }
    final sorted = _days.toList()..sort();
    return sorted.map((d) => weekdayLabels[d - 1]).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accentColor = scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Add Alarm',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColor,
                              ),
                            )
                          : Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: _selectedDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime newDateTime) {
                      setState(() {
                        _selectedDateTime = newDateTime;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Exercise',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: scheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              IosModePill(
                                label: 'Squats',
                                selected: _mode == ExerciseMode.squat,
                                onTap: () =>
                                    setState(() => _mode = ExerciseMode.squat),
                              ),
                              const SizedBox(width: 6),
                              IosModePill(
                                label: 'Push-ups',
                                selected: _mode == ExerciseMode.pushup,
                                onTap: () =>
                                    setState(() => _mode = ExerciseMode.pushup),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: scheme.outline.withValues(alpha: 0.2),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reps',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: scheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              IosStepButton(
                                icon: Icons.remove,
                                tooltip: 'Decrease reps',
                                onTap: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  setState(
                                    () => _reps = (_reps - 5).clamp(5, 100),
                                  );
                                },
                              ),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  '$_reps',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              IosStepButton(
                                icon: Icons.add,
                                tooltip: 'Increase reps',
                                onTap: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  setState(
                                    () => _reps = (_reps + 5).clamp(5, 100),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: scheme.outline.withValues(alpha: 0.2),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Repeat',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                _recurrenceSummary,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(7, (i) {
                              final day = i + 1;
                              final selected = _days.contains(day);
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i == 6 ? 0 : 4,
                                  ),
                                  child: IosDayToggle(
                                    label: weekdayLabels[i],
                                    tooltip: weekdayFullLabels[i],
                                    selected: selected,
                                    onTap: () => setState(() {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      final next = {..._days};
                                      selected
                                          ? next.remove(day)
                                          : next.add(day);
                                      _days = next;
                                    }),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alarm_on, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatTargetSummary(_targetDateTime),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
