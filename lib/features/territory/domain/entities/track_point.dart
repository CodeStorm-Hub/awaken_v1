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

  @override
  List<Object?> get props => [latitude, longitude, accuracy, timestamp];
}
