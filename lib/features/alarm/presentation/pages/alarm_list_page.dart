import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../onboarding/presentation/pages/battery_exemption_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
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
/// handoff "AlarmListScreen"). Enabled/disabled is presentation-only, same
/// as the design prototype — the domain layer has no per-alarm toggle
/// use case yet, only schedule/cancel.
class AlarmListPage extends StatefulWidget {
  const AlarmListPage({super.key});

  @override
  State<AlarmListPage> createState() => _AlarmListPageState();
}

class _AlarmListPageState extends State<AlarmListPage> {
  // Tracked as "disabled" (not "enabled") ids, defaulting empty, so any
  // newly-scheduled alarm is enabled by default without needing to
  // backfill it into a separate enabled-set on every alarms-list change.
  final Set<String> _disabled = {};

  void _toggle(String id) {
    setState(() {
      if (!_disabled.add(id)) _disabled.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: BlocBuilder<AlarmCubit, AlarmState>(
          builder: (context, state) {
            final alarms = state.alarms;
            final n = alarms.length;

            return Stack(
              // Stack defaults to StackFit.loose, which lets this Column
              // shrink-wrap to its content's natural width instead of
              // filling the screen — that shifted the whole page (title,
              // empty state) left instead of centering/filling properly.
              // StackFit.expand forces it to the Stack's full bounds; the
              // FAB below is `Positioned` so it's unaffected either way.
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.battery_charging_full),
                                tooltip: 'Alarm reliability settings',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const BatteryExemptionPage(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.bug_report_outlined),
                                tooltip: 'Run alarm reliability self-test',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AlarmReliabilityTestPage(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _ProfileButton(
                            scheme: scheme,
                            onTap: () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alarms',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n == 0
                                ? 'Nothing scheduled'
                                : '$n alarm${n == 1 ? '' : 's'} · tap one to preview the wake-up flow',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: n == 0
                          ? _EmptyState(scheme: scheme, theme: theme)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                              itemCount: n,
                              separatorBuilder: (_, _) => const SizedBox(height: 3),
                              itemBuilder: (context, index) {
                                final alarm = alarms[index];
                                final on = !_disabled.contains(alarm.id);
                                return _RiseIn(
                                  delay: Duration(milliseconds: index * 60),
                                  child: _AlarmCard(
                                    alarm: alarm,
                                    on: on,
                                    radius: groupedItemRadius(index: index, count: n),
                                    onToggle: () => _toggle(alarm.id),
                                    onDelete: () => _confirmDelete(context, alarm),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => AlarmRingPage(alarm: alarm)),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                Positioned(
                  right: 18,
                  bottom: 24,
                  child: _ExpressiveFab(onPressed: () => _showScheduleSheet(context)),
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
        onSchedule: (mode, reps, minutes, days) {
          final scheduledTime = DateTime.now().add(Duration(minutes: minutes));
          cubit.schedule(
            AlarmSchedule(
              id: const Uuid().v4(),
              scheduledTime: scheduledTime,
              exerciseMode: mode,
              requiredReps: reps,
              recurringDays: days,
            ),
          );
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Alarm scheduled for '
                '${scheduledTime.hour.toString().padLeft(2, '0')}:'
                '${scheduledTime.minute.toString().padLeft(2, '0')}',
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AlarmSchedule alarm) async {
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<AlarmCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      // Flutter's default barrier is a hardcoded Colors.black54 — using
      // scheme.scrim instead keeps the barrier consistent with the rest of
      // the Material 3 theme (it's the same tone the seed/dynamic color
      // algorithm derives for exactly this purpose).
      barrierColor: scheme.scrim.withValues(alpha: 0.5),
      builder: (_) => AlertDialog(
        title: const Text('Delete alarm?'),
        content: const Text('This alarm will be cancelled and removed from your schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    cubit.cancel(alarm.id);
    messenger.showSnackBar(const SnackBar(content: Text('Alarm deleted')));
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.scheme, required this.onTap});

  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Profile',
      child: Material(
        color: scheme.secondaryContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                'G',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // `Expanded` only controls the outer Column's main (vertical) axis; on
    // the cross axis this child still gets a loose width constraint, so
    // without forcing full width here, this whole block shrink-wraps to
    // its widest line of text and sits flush against the outer Column's
    // `crossAxisAlignment.start` — i.e. off-center — instead of centering
    // across the screen.
    return SizedBox(
      width: double.infinity,
      child: Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          ExpressiveFlower(
            size: 108,
            color: scheme.secondaryContainer,
            child: Icon(Icons.alarm_add, size: 44, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: 16),
          Text(
            'No alarms scheduled',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 220,
            child: Text(
              'Schedule one and earn tomorrow morning.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Staggered entrance for each alarm card (handoff's `m3x-rise` keyframe:
/// fade + rise-up + slight scale-in, played once per card with a
/// `60ms * index` stagger). Gated on `_played` — since `AlarmListPage`
/// rebuilds its `ListView` on every toggle/delete, this must not replay
/// on every parent rebuild, only on this card's first appearance.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> {
  bool _played = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _played = true);
    });
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
    final bg = on ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final chipBg = on ? Colors.white.withValues(alpha: 0.55) : scheme.surfaceContainer;

    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _timeLabel,
                    style: TextStyle(
                      fontSize: 44,
                      height: 48 / 44,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  ExpressiveSwitch(value: on, onChanged: (_) => onToggle()),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Chip(
                    bg: chipBg,
                    fg: fg,
                    icon: alarm.exerciseMode == ExerciseMode.squat
                        ? Icons.accessibility_new
                        : Icons.sports_gymnastics,
                    label:
                        '${alarm.requiredReps} ${alarm.exerciseMode == ExerciseMode.squat ? 'squats' : 'push-ups'}',
                  ),
                  _Chip(bg: chipBg, fg: fg, label: _recurrenceLabel),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: fg,
                  onPressed: onDelete,
                  tooltip: 'Delete alarm',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.bg, required this.fg, required this.label, this.icon});

  final Color bg;
  final Color fg;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
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
          transform: Matrix4.diagonal3Values(_pressed ? 1.06 : 1, _pressed ? 1.06 : 1, 1),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(_pressed ? 999 : 22),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
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

  final void Function(ExerciseMode mode, int reps, int minutes, Set<int> days) onSchedule;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  var _mode = ExerciseMode.squat;
  var _reps = 20;
  var _minutes = 1;
  var _days = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              'Schedule alarm',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Squats',
                    icon: Icons.accessibility_new,
                    selected: _mode == ExerciseMode.squat,
                    onTap: () => setState(() => _mode = ExerciseMode.squat),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: _ModeButton(
                    label: 'Push-ups',
                    icon: Icons.sports_gymnastics,
                    selected: _mode == ExerciseMode.pushup,
                    onTap: () => setState(() => _mode = ExerciseMode.pushup),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Stepper(
              label: 'Reps',
              value: '$_reps',
              decrementLabel: 'Fewer reps',
              incrementLabel: 'More reps',
              radius: const BorderRadius.vertical(
                top: Radius.circular(18),
                bottom: Radius.circular(8),
              ),
              onDecrement: () => setState(() => _reps = (_reps - 5).clamp(5, 100)),
              onIncrement: () => setState(() => _reps = (_reps + 5).clamp(5, 100)),
            ),
            const SizedBox(height: 3),
            _Stepper(
              label: 'Minutes from now',
              value: '$_minutes',
              decrementLabel: 'Sooner',
              incrementLabel: 'Later',
              radius: const BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(18),
              ),
              onDecrement: () => setState(() => _minutes = (_minutes - 1).clamp(1, 720)),
              onIncrement: () => setState(() => _minutes = (_minutes + 1).clamp(1, 720)),
            ),
            const SizedBox(height: 16),
            Text(
              'Repeat',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _days.contains(day);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
                    child: _DayToggle(
                      label: _weekdayLabels[i],
                      tooltip: _weekdayFullLabels[i],
                      selected: selected,
                      onTap: () => setState(() {
                        final next = {..._days};
                        selected ? next.remove(day) : next.add(day);
                        _days = next;
                      }),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    onPressed: () {
                      widget.onSchedule(_mode, _reps, _minutes, _days);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Schedule alarm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(selected ? 999 : 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check : icon,
                size: 20,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.radius,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String value;
  final String decrementLabel;
  final String incrementLabel;
  final BorderRadius radius;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: radius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurface, fontSize: 16)),
          Row(
            children: [
              _StepButton(icon: Icons.remove, label: decrementLabel, onTap: onDecrement),
              SizedBox(
                width: 44,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _StepButton(icon: Icons.add, label: incrementLabel, onTap: onIncrement),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(_pressed ? 999 : 14);
    return Tooltip(
      message: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: Material(
          color: scheme.secondaryContainer,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: 44,
              height: 44,
              decoration: BoxDecoration(borderRadius: radius),
              child: Icon(widget.icon, size: 20, color: scheme.onSecondaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? scheme.tertiaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(selected ? 14 : 999),
            // `outline`, not `outlineVariant` — this border is the only thing
            // conveying "unselected day" (WCAG 1.4.11 needs 3:1 for
            // functional boundaries; outlineVariant here measured ~1.6:1).
            border: selected ? null : Border.all(color: scheme.outline),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
