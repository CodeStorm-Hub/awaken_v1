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
  /// most a week ahead (today included) — always terminates.
  ///
  /// Starts at `daysAhead = 0` (today) rather than `1` — every call site
  /// only invokes this for startup/reschedule repair when the stored
  /// `scheduledTime` is already in the past, so if today is a recurring
  /// day and today's time-of-day slot hasn't happened yet, that's the
  /// correct next occurrence, not next week's. Previously the loop always
  /// skipped today entirely, so a same-day repair (e.g. app relaunched
  /// mid-morning after a crash, with today's slot still hours away) would
  /// jump a full week ahead instead of firing later today.
  DateTime? nextOccurrenceAfter(DateTime from) {
    if (recurringDays.isEmpty) return null;
    final fromDate = DateTime(from.year, from.month, from.day);
    for (var daysAhead = 0; daysAhead <= 7; daysAhead++) {
      final candidateDate = fromDate.add(Duration(days: daysAhead));
      if (!recurringDays.contains(candidateDate.weekday)) continue;
      final candidate = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );
      if (candidate.isAfter(from)) return candidate;
    }
    return null; // unreachable while recurringDays is non-empty
  }

  /// First fire time for a newly created alarm — the counterpart to
  /// [nextOccurrenceAfter] used at scheduling time, when there's no existing
  /// instance to call it on yet. For an empty [recurringDays] this is the
  /// next today/tomorrow slot at [timeOfDay]'s hour/minute (today if still
  /// ahead of [from], else tomorrow) — the one-shot semantics the schedule
  /// sheet already relied on. For a non-empty set it delegates to
  /// [nextOccurrenceAfter] via a throwaway probe instance so both paths stay
  /// on one source of truth: previously the schedule sheet computed a
  /// today/tomorrow slot unconditionally and ignored the selected weekdays
  /// entirely, so e.g. picking "Saturday" only on a Monday scheduled the
  /// first ring for Tuesday instead of the coming Saturday.
  static DateTime firstOccurrence({
    required DateTime timeOfDay,
    required Set<int> recurringDays,
    required DateTime from,
  }) {
    if (recurringDays.isEmpty) {
      var dt = DateTime(
        from.year,
        from.month,
        from.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
      if (!dt.isAfter(from)) dt = dt.add(const Duration(days: 1));
      return dt;
    }
    final probe = AlarmSchedule(
      id: '',
      scheduledTime: DateTime(
        from.year,
        from.month,
        from.day,
        timeOfDay.hour,
        timeOfDay.minute,
      ),
      exerciseMode: ExerciseMode.squat,
      requiredReps: 0,
      recurringDays: recurringDays,
    );
    return probe.nextOccurrenceAfter(from)!;
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
  List<Object?> get props => [
    id,
    scheduledTime,
    exerciseMode,
    requiredReps,
    penaltyMultiplier,
    isActive,
    recurringDays,
  ];
}
