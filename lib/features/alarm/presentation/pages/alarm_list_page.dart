import 'dart:async';

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
import '../widgets/alarm_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/expressive_fab.dart';
import '../widgets/rise_in.dart';
import '../widgets/schedule_sheet.dart';
import 'alarm_reliability_test_page.dart';
import 'alarm_ring_page.dart';

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
                          ? EmptyState(scheme: scheme, theme: theme)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                120,
                              ),
                              itemCount: n,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 3),
                              itemBuilder: (context, index) {
                                final alarm = alarms[index];
                                return RiseIn(
                                  key: ValueKey(alarm.id),
                                  delay: Duration(
                                    milliseconds: index * 60,
                                  ),
                                  child: AlarmCard(
                                    alarm: alarm,
                                    on: alarm.isActive,
                                    radius: groupedItemRadius(
                                      index: index,
                                      count: n,
                                    ),
                                    onToggle: () => _toggleActive(
                                      context,
                                      alarm,
                                    ),
                                    onDelete: () => _confirmDelete(
                                      context,
                                      alarm,
                                    ),
                                    onTap: () => Navigator.of(
                                      context,
                                    ).push(
                                      MaterialPageRoute(
                                        builder: (_) => AlarmRingPage(
                                          alarm: alarm,
                                          isPreview: true,
                                        ),
                                      ),
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
                  child: ExpressiveFab(
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
      builder: (_) => ScheduleSheet(
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
