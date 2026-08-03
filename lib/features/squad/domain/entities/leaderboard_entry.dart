import 'package:equatable/equatable.dart';

import 'streak_tier.dart';

/// One row of `squad_leaderboard()` — `rank` is derived client-side from
/// the RPC's already-sorted (by `area_sqm` desc) result order, not stored.
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.streakTier,
    required this.areaSqm,
    required this.isYou,
    this.avatarUrl,
  });

  final int rank;
  final String userId;
  final String displayName;
  final StreakTier streakTier;
  final double areaSqm;
  final bool isYou;

  /// From `profiles.avatar_url` — null for accounts that have never linked
  /// Google (or any other provider whose metadata carries a photo).
  final String? avatarUrl;

  @override
  List<Object?> get props => [
    rank,
    userId,
    displayName,
    streakTier,
    areaSqm,
    isYou,
    avatarUrl,
  ];
}
