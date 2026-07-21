import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../onboarding/presentation/pages/battery_exemption_page.dart';
import '../../domain/entities/alarm_schedule.dart';
import '../bloc/alarm_cubit.dart';
import '../bloc/alarm_state.dart';
import 'alarm_reliability_test_page.dart';

/// Phase 1 scope: functional alarm list + quick-schedule dialog. The full
/// M3 Expressive Alarm Management Dashboard (UI/UX plan §2) is a later
/// design pass — this page exists to exercise and prove the scheduling
/// pipeline end-to-end.
class AlarmListPage extends StatelessWidget {
  const AlarmListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Awaken'),
        actions: [
          IconButton(
            icon: const Icon(Icons.battery_charging_full),
            tooltip: 'Alarm reliability settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BatteryExemptionPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Run alarm reliability self-test',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlarmReliabilityTestPage()),
            ),
          ),
        ],
      ),
      body: BlocBuilder<AlarmCubit, AlarmState>(
        builder: (context, state) {
          if (state.alarms.isEmpty) {
            return const Center(child: Text('No alarms scheduled.'));
          }
          return ListView.builder(
            itemCount: state.alarms.length,
            itemBuilder: (context, index) {
              final alarm = state.alarms[index];
              return ListTile(
                title: Text(_timeLabel(alarm.scheduledTime)),
                subtitle: Text(
                  '${alarm.exerciseMode.name} · ${alarm.requiredReps} reps · '
                  '${_recurrenceLabel(alarm.recurringDays)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => context.read<AlarmCubit>().cancel(alarm.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScheduleDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _timeLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _recurrenceLabel(Set<int> recurringDays) {
    if (recurringDays.isEmpty) return 'One-time';
    if (recurringDays.length == 7) return 'Every day';
    final sorted = recurringDays.toList()..sort();
    return sorted.map((day) => _weekdayLabels[day - 1]).join(', ');
  }

  Future<void> _showScheduleDialog(BuildContext context) async {
    final cubit = context.read<AlarmCubit>();
    var mode = ExerciseMode.squat;
    var reps = 20;
    var minutesFromNow = 1;
    var recurringDays = <int>{};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Schedule alarm'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<ExerciseMode>(
                    value: mode,
                    items: ExerciseMode.values
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                        .toList(),
                    onChanged: (value) => setState(() => mode = value ?? mode),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reps'),
                      Text('$reps'),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => setState(() => reps = (reps - 5).clamp(5, 100)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => reps = (reps + 5).clamp(5, 100)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Minutes from now'),
                      Text('$minutesFromNow'),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () =>
                            setState(() => minutesFromNow = (minutesFromNow - 1).clamp(1, 720)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () =>
                            setState(() => minutesFromNow = (minutesFromNow + 1).clamp(1, 720)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Repeat',
                      style: Theme.of(dialogContext).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: List.generate(7, (i) {
                      final day = i + 1; // DateTime.monday..sunday
                      return FilterChip(
                        label: Text(_weekdayLabels[i]),
                        selected: recurringDays.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            recurringDays = {...recurringDays, day};
                          } else {
                            recurringDays = {...recurringDays}..remove(day);
                          }
                        }),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    cubit.schedule(
                      AlarmSchedule(
                        id: const Uuid().v4(),
                        scheduledTime: DateTime.now().add(Duration(minutes: minutesFromNow)),
                        exerciseMode: mode,
                        requiredReps: reps,
                        recurringDays: recurringDays,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
