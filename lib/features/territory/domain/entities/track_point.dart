import 'package:equatable/equatable.dart';

/// A single smoothed GPS fix captured during a run.
class TrackPoint extends Equatable {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  /// Used to persist run-tracking checkpoints (see `RunTrackingRepositoryImpl`
  /// — periodic disk snapshots so an interrupted run can resume instead of
  /// being silently lost).
  Map<String, Object?> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'acc': accuracy,
    'ts': timestamp.toIso8601String(),
  };

  factory TrackPoint.fromJson(Map<String, Object?> json) => TrackPoint(
    latitude: json['lat']! as double,
    longitude: json['lng']! as double,
    accuracy: json['acc']! as double,
    timestamp: DateTime.parse(json['ts']! as String),
  );

  @override
  List<Object?> get props => [latitude, longitude, accuracy, timestamp];
}
