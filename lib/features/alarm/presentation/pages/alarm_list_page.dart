import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../onboarding/presentation/pages/battery_exemption_page.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../../domain/entities/alarm_schedule.dart';
import '../bloc/alarm_cubit.dart';
import '../bloc/alarm_state.dart';
import 'alarm_reliability_test_page.dart';
import 'alarm_ring_page.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _weekdayFullLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// M3 Expressive Alarm Management Dashboard (UI/UX plan §2 / Claude Design
/// handoff "AlarmListScreen"). Enable/disable persists through
/// `AlarmCubit.setActive` (plan §6 Phase 6.5) — `alarm.isActive` on the
/// merged native+Drift stream (see `AlarmRepositoryImpl.watchAlarms`) is
/// the single source of truth, not local widget state.
class AlarmListPage extends StatefulWidget {
  const AlarmListPage({super.key});

  @override
  State<AlarmListPage> createState() => _AlarmListPageState();
}

class _AlarmListPageState extends State<AlarmListPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        // Only `state.alarms` is ever read below — `AlarmCubit` is a single
        // app-wide instance (also driving `app.dart`'s ring overlay), so
        // without this `buildWhen` a `ringingAlarm`/`verificationInProgress`/
        // `currentTaxMultiplier` change elsewhere (e.g. an alarm firing
        // while this tab is open) rebuilt this whole page — including its
        // `AppleGlassContainer`/`BackdropFilter` header — for state this
        // page doesn't even render.
        child: BlocBuilder<AlarmCubit, AlarmState>(
          buildWhen: (previous, current) => previous.alarms != current.alarms,
          builder: (context, state) {
            final alarms = state.alarms;
            final n = alarms.length;

            return Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: AppleGlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alarms',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  n == 0
                                      ? 'Nothing scheduled'
                                      : '$n alarm${n == 1 ? '' : 's'} · tap to preview',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: secondaryLabelColor(context),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Tooltip(
                                  message: 'Alarm reliability settings',
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const BatteryExemptionPage(),
                                        ),
                                      ),
                                      // Was 36x36 — below WCAG 2.5.5's
                                      // 44x44 minimum; icon stays the same
                                      // visual size.
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Icon(
                                          Icons.battery_charging_full,
                                          size: 18,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Run self-test',
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AlarmReliabilityTestPage(),
                                        ),
                                      ),
                                      // Was 36x36 — below WCAG 2.5.5's
                                      // 44x44 minimum; icon stays the same
                                      // visual size.
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Icon(
                                          Icons.bug_report_outlined,
                                          size: 18,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const CurrentUserAvatarButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: n == 0
                          ? _EmptyState(scheme: scheme, theme: theme)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                120,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Column(
                                        children: [
                                          for (
                                            var index = 0;
                                            index < n;
                                            index++
                                          ) ...[
                                            if (index > 0)
                                              const SizedBox(height: 3),
                                            Builder(
                                              builder: (context) {
                                                final alarm = alarms[index];
                                                return _RiseIn(
                                                  // Keyed by alarm id, not
                                                  // position — without this,
                                                  // deleting/reordering an
                                                  // alarm shifted every
                                                  // element below it down one
                                                  // index, and `_RiseIn`'s
                                                  // `State` (keyed
                                                  // positionally by default)
                                                  // stayed attached to that
                                                  // index rather than
                                                  // following its alarm,
                                                  // replaying the entry
                                                  // animation on the wrong
                                                  // card and briefly showing
                                                  // stale content during the
                                                  // transition.
                                                  key: ValueKey(alarm.id),
                                                  delay: Duration(
                                                    milliseconds: index * 60,
                                                  ),
                                                  child: _AlarmCard(
                                                    alarm: alarm,
                                                    on: alarm.isActive,
                                                    radius: groupedItemRadius(
                                                      index: index,
                                                      count: n,
                                                    ),
                                                    onToggle: () =>
                                                        _toggleActive(
                                                          context,
                                                          alarm,
                                                        ),
                                                    onDelete: () =>
                                                        _confirmDelete(
                                                          context,
                                                          alarm,
                                                        ),
                                                    onTap: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).push(
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                AlarmRingPage(
                                                                  alarm: alarm,
                                                                  isPreview:
                                                                      true,
                                                                ),
                                                          ),
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
                Positioned(
                  right: 18,
                  bottom: 24,
                  child: _ExpressiveFab(
                    onPressed: () => _showScheduleSheet(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showScheduleSheet(BuildContext context) async {
    final cubit = context.read<AlarmCubit>();
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleSheet(
        onSchedule: (mode, reps, scheduledTime, days) async {
          try {
            await cubit.schedule(
              AlarmSchedule(
                id: const Uuid().v4(),
                scheduledTime: scheduledTime,
                exerciseMode: mode,
                requiredReps: reps,
                recurringDays: days,
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Could not schedule alarm: $e')),
            );
            return;
          }
          final hourStr = scheduledTime.hour.toString().padLeft(2, '0');
          final minStr = scheduledTime.minute.toString().padLeft(2, '0');
          messenger.showSnackBar(
            SnackBar(content: Text('Alarm scheduled for $hourStr:$minStr')),
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, AlarmSchedule alarm) async {
    unawaited(HapticFeedback.lightImpact());
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<AlarmCubit>();
    try {
      await cubit.setActive(alarm.id, !alarm.isActive);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update alarm: $e')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, AlarmSchedule alarm) async {
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<AlarmCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: scheme.scrim.withValues(alpha: 0.5),
      builder: (_) => AlertDialog(
        title: const Text('Delete alarm?'),
        content: const Text(
          'This alarm will be cancelled and removed from your schedule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await cubit.cancel(alarm.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete alarm: $e')),
      );
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Alarm deleted')));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Column(
          children: [
            ExpressiveFlower(
              size: 108,
              color: scheme.secondaryContainer,
              // Light theme's `secondaryContainer` (`0xFFE5E5EA`) sits only
              // ~1.05:1 from the page surface (`0xFFF2F2F7`) — with no
              // border, this badge is effectively invisible in light mode
              // (see `ExpressiveFlower`'s own doc comment on `borderColor`).
              borderColor: scheme.outline,
              child: Icon(
                Icons.alarm_add,
                size: 44,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No alarms scheduled',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 220,
              child: Text(
                'Schedule one and earn tomorrow morning.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.delay, required this.child, super.key});

  final Duration delay;
  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> {
  bool _played = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _played = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _played ? Offset.zero : const Offset(0, 0.12),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _played ? 1 : 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
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
    return sorted.map((d) => _weekdayLabels[d - 1]).join(', ');
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
                            _Chip(
                              bg: chipBg,
                              fg: chipFg,
                              icon: alarm.exerciseMode == ExerciseMode.squat
                                  ? Icons.accessibility_new
                                  : Icons.sports_gymnastics,
                              label:
                                  '${alarm.requiredReps} ${alarm.exerciseMode == ExerciseMode.squat ? 'squats' : 'push-ups'}',
                            ),
                            _Chip(
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.bg,
    required this.fg,
    required this.label,
    this.icon,
  });

  final Color bg;
  final Color fg;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressiveFab extends StatefulWidget {
  const _ExpressiveFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ExpressiveFab> createState() => _ExpressiveFabState();
}

class _ExpressiveFabState extends State<_ExpressiveFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Add alarm',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          width: 68,
          height: 68,
          transform: Matrix4.diagonal3Values(
            _pressed ? 1.06 : 1,
            _pressed ? 1.06 : 1,
            1,
          ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(_pressed ? 999 : 22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.add, size: 30, color: scheme.onPrimary),
        ),
      ),
    );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.onSchedule});

  final Future<void> Function(
    ExerciseMode mode,
    int reps,
    DateTime scheduledTime,
    Set<int> days,
  )
  onSchedule;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
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
        : _weekdayFullLabels[scheduled.weekday - 1];

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
    return sorted.map((d) => _weekdayLabels[d - 1]).join(', ');
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
                              _IosModePill(
                                label: 'Squats',
                                selected: _mode == ExerciseMode.squat,
                                onTap: () =>
                                    setState(() => _mode = ExerciseMode.squat),
                              ),
                              const SizedBox(width: 6),
                              _IosModePill(
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
                              _IosStepButton(
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
                              _IosStepButton(
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
                                  child: _IosDayToggle(
                                    label: _weekdayLabels[i],
                                    tooltip: _weekdayFullLabels[i],
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

class _IosModePill extends StatelessWidget {
  const _IosModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;
    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.surfaceContainer;
    final unselectedFg = isDark ? Colors.white70 : scheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Was ~26dp tall (padding-driven, no minimum) — below WCAG 2.5.5's
      // 48dp minimum. `SizedBox`+`Center` extends the tap area without
      // changing the pill's visual size, same pattern as `ExpressiveSwitch`.
      child: SizedBox(
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? accentColor : unselectedBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : unselectedFg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosStepButton extends StatelessWidget {
  const _IosStepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : scheme.surfaceContainer;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Was 32x32 — below WCAG 2.5.5's 48x48 minimum; circle stays the
        // same visual size, centered in a larger tap area.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: accentColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosDayToggle extends StatelessWidget {
  const _IosDayToggle({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;
    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.surfaceContainer;
    final unselectedFg = isDark ? Colors.white70 : scheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Was 36dp tall — below WCAG 2.5.5's 48dp minimum. Seven of these
        // sit in a row on a narrow phone with no horizontal room to grow,
        // so unlike the pill/stepper fixes above, height grows in place
        // instead of via a separate hit-area wrapper.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: selected ? accentColor : unselectedBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : unselectedFg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
