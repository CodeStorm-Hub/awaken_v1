import 'package:equatable/equatable.dart';

enum ExerciseMode { squat, pushup }

class AlarmSchedule extends Equatable {
  const AlarmSchedule({
    required this.id,
    required this.scheduledTime,
    required this.exerciseMode,
    required this.requiredReps,
    this.penaltyMultiplier = 1.0,
    this.isActive = true,
    this.recurringDays = const {},
  });

  /// Client-generated UUIDv4 — the domain/Supabase identity. The native
  /// `alarm` package needs a 32-bit int id instead; that mapping lives in
  /// the data layer (AlarmRepositoryImpl), not here.
  final String id;

  final DateTime scheduledTime;
  final ExerciseMode exerciseMode;
  final int requiredReps;

  /// Superseded by the global, per-user wake-up tax (see
  /// `AlarmRepository.watchCurrentTaxMultiplier` / `WakeUpTaxStore`) — a
  /// per-alarm multiplier was gameable by deleting and recreating the
  /// alarm. Kept on the entity/schema for compatibility; `completeWorkout`
  /// no longer mutates it, so it stays at its default.
  final double penaltyMultiplier;

  final bool isActive;

  /// `DateTime.monday`(1)..`DateTime.sunday`(7). Empty means one-shot —
  /// `scheduledTime` fires once and the alarm is done. Non-empty means
  /// `scheduledTime`'s time-of-day repeats on these weekdays (plan
  /// discussion: "days-of-week" recurrence, not a general RRULE system).
  final Set<int> recurringDays;

  bool get isRecurring => recurringDays.isNotEmpty;

  /// The next fire time strictly after [from] that matches
  /// [recurringDays], at the same time-of-day as [scheduledTime]. Null for
  /// a one-shot alarm (or the pathological case of an empty set). Scans at
  /// most a week ahead — always terminates.
  DateTime? nextOccurrenceAfter(DateTime from) {
    if (recurringDays.isEmpty) return null;
    final fromDate = DateTime(from.year, from.month, from.day);
    for (var daysAhead = 1; daysAhead <= 7; daysAhead++) {
      final candidateDate = fromDate.add(Duration(days: daysAhead));
      if (recurringDays.contains(candidateDate.weekday)) {
        return DateTime(
          candidateDate.year,
          candidateDate.month,
          candidateDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );
      }
    }
    return null; // unreachable while recurringDays is non-empty
  }

  AlarmSchedule copyWith({
    DateTime? scheduledTime,
    ExerciseMode? exerciseMode,
    int? requiredReps,
    double? penaltyMultiplier,
    bool? isActive,
    Set<int>? recurringDays,
  }) {
    return AlarmSchedule(
      id: id,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      exerciseMode: exerciseMode ?? this.exerciseMode,
      requiredReps: requiredReps ?? this.requiredReps,
      penaltyMultiplier: penaltyMultiplier ?? this.penaltyMultiplier,
      isActive: isActive ?? this.isActive,
      recurringDays: recurringDays ?? this.recurringDays,
    );
  }

  @override
  List<Object?> get props =>
      [id, scheduledTime, exerciseMode, requiredReps, penaltyMultiplier, isActive, recurringDays];
}
