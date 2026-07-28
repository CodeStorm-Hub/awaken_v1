import 'package:injectable/injectable.dart';

import '../entities/leaderboard_entry.dart';
import '../repositories/squad_repository.dart';

class GetNearbyLeaderboardParams {
  const GetNearbyLeaderboardParams({
    required this.radiusM,
    required this.timeWindow,
    this.rowLimit = 50,
  });

  final double radiusM;

  /// `'all_time'`, `'weekly'`, or `'daily'`.
  final String timeWindow;
  final int rowLimit;
}

@injectable
class GetNearbyLeaderboard {
  GetNearbyLeaderboard(this._repository);

  final SquadRepository _repository;

  Future<List<LeaderboardEntry>> call(GetNearbyLeaderboardParams params) =>
      _repository.fetchNearbyLeaderboard(
        radiusM: params.radiusM,
        timeWindow: params.timeWindow,
        rowLimit: params.rowLimit,
      );
}
