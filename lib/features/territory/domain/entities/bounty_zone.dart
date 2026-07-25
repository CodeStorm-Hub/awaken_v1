import 'package:equatable/equatable.dart';

/// An active bounty zone (refined territory plan item 1) — public-read,
/// server-seeded (no client create/update path).
class BountyZone extends Equatable {
  const BountyZone({
    required this.id,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.multiplier,
  });

  final String id;
  final double centerLat;
  final double centerLng;
  final double radiusM;
  final double multiplier;

  @override
  List<Object?> get props => [id, centerLat, centerLng, radiusM, multiplier];
}
