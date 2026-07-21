import 'dart:convert';

import '../../domain/entities/alarm_schedule.dart';

/// The `alarm` package only carries a title/body/dateTime natively — our
/// structured fields (UUID identity, exercise mode, reps, penalty) ride
/// along in `AlarmSettings.payload` as JSON. This is Phase 1 persistence;
/// it moves to Drift once the offline-first data layer lands (plan §6
/// Phase 3), at which point AlarmSettings.id becomes a pure native handle.
class AlarmPayload {
  const AlarmPayload({
    required this.id,
    required this.exerciseMode,
    required this.requiredReps,
    required this.penaltyMultiplier,
    this.recurringDays = const {},
  });

  final String id;
  final ExerciseMode exerciseMode;
  final int requiredReps;
  final double penaltyMultiplier;

  /// `DateTime.weekday` values — see `AlarmSchedule.recurringDays`. This is
  /// the only place recurrence is persisted (the native `alarm` package's
  /// stored settings, not Drift), since `AlarmRepositoryImpl.watchAlarms()`
  /// reconstructs `AlarmSchedule`s from here.
  final Set<int> recurringDays;

  factory AlarmPayload.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return AlarmPayload(
      id: json['id'] as String,
      exerciseMode: ExerciseMode.values.byName(json['exerciseMode'] as String),
      requiredReps: json['requiredReps'] as int,
      penaltyMultiplier: (json['penaltyMultiplier'] as num).toDouble(),
      recurringDays: ((json['recurringDays'] as List<dynamic>?) ?? const [])
          .map((d) => d as int)
          .toSet(),
    );
  }

  String toJson() => jsonEncode({
        'id': id,
        'exerciseMode': exerciseMode.name,
        'requiredReps': requiredReps,
        'penaltyMultiplier': penaltyMultiplier,
        'recurringDays': recurringDays.toList(),
      });

  /// Derives a stable 32-bit positive int from the UUID for the native
  /// `alarm` package's id field (it doesn't accept string ids). Collision
  /// risk is negligible for a single user's small alarm count.
  static int nativeId(String uuid) => uuid.hashCode & 0x7FFFFFFF;
}
