import 'package:injectable/injectable.dart';

import '../entities/leaderboard_entry.dart';
import '../repositories/squad_repository.dart';

class GetNearbyLeaderboardParams {
  const GetNearbyLeaderboardParams({
    required this.radiusM,
    required this.weekly,
  });

  final double radiusM;
  final bool weekly;
}

@injectable
class GetNearbyLeaderboard {
  GetNearbyLeaderboard(this._repository);

  final SquadRepository _repository;

  Future<List<LeaderboardEntry>> call(GetNearbyLeaderboardParams params) =>
      _repository.fetchNearbyLeaderboard(
        radiusM: params.radiusM,
        weekly: params.weekly,
      );
}
