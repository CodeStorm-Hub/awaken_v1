import 'package:injectable/injectable.dart';

import '../entities/leaderboard_entry.dart';
import '../repositories/squad_repository.dart';

@injectable
class GetGlobalLeaderboard {
  GetGlobalLeaderboard(this._repository);

  final SquadRepository _repository;

  Future<List<LeaderboardEntry>> call({required bool weekly}) =>
      _repository.fetchGlobalLeaderboard(weekly: weekly);
}
