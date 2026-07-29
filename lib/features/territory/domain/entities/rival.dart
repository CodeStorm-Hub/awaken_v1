import 'package:equatable/equatable.dart';

/// The caller's most recent contested capture, either direction — from
/// `current_rival()` (refined territory plan item 3).
class Rival extends Equatable {
  const Rival({
    required this.rivalId,
    required this.rivalDisplayName,
    required this.areaTakenSqm,
    required this.asWinner,
    required this.occurredAt,
    this.territoryLat,
    this.territoryLng,
  });

  final String rivalId;
  final String? rivalDisplayName;
  final double areaTakenSqm;

  /// True if the caller took land from [rivalId]; false if [rivalId] took
  /// land from the caller.
  final bool asWinner;
  final DateTime occurredAt;

  /// Centroid of the rival's largest current territory, from
  /// `current_rival()`'s `rival_territory_lat`/`rival_territory_lng` columns
  /// — null if the rival currently owns no territory.
  final double? territoryLat;
  final double? territoryLng;

  @override
  List<Object?> get props => [
    rivalId,
    rivalDisplayName,
    areaTakenSqm,
    asWinner,
    occurredAt,
    territoryLat,
    territoryLng,
  ];
}
