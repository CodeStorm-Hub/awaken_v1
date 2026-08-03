import 'package:equatable/equatable.dart';

/// A territory within the decay warning window — from
/// `my_territories_at_risk()` (refined territory plan item 1).
class TerritoryAtRisk extends Equatable {
  const TerritoryAtRisk({
    required this.id,
    required this.areaSqm,
    required this.lastDefendedAt,
    required this.expiresAt,
  });

  final String id;
  final double areaSqm;
  final DateTime lastDefendedAt;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [id, areaSqm, lastDefendedAt, expiresAt];
}
