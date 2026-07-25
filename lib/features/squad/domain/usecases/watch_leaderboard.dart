import 'package:injectable/injectable.dart';

import '../entities/leaderboard_entry.dart';
import '../repositories/squad_repository.dart';

@injectable
class WatchLeaderboard {
  WatchLeaderboard(this._repository);

  final SquadRepository _repository;

  Stream<List<LeaderboardEntry>> call(String squadId) =>
      _repository.watchLeaderboard(squadId);
}
