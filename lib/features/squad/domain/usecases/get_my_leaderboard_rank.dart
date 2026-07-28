import 'package:injectable/injectable.dart';

import '../repositories/squad_repository.dart';

/// Caller's own rank in the nearby/global leaderboard sheet — an
/// independent targeted query (`my_global_rank`/`my_nearby_rank` RPCs)
/// backing the sheet's pinned "You: #N" row, rather than scanning the
/// (page-limited) fetched list client-side. Null if the caller isn't
/// rankable yet (no captured area / no `last_run_location`).
@injectable
class GetMyLeaderboardRank {
  GetMyLeaderboardRank(this._repository);

  final SquadRepository _repository;

  Future<int?> call({
    required bool nearby,
    required String timeWindow,
    double radiusM = 5000,
  }) {
    return nearby
        ? _repository.fetchMyNearbyRank(
            radiusM: radiusM,
            timeWindow: timeWindow,
          )
        : _repository.fetchMyGlobalRank(timeWindow: timeWindow);
  }
}
