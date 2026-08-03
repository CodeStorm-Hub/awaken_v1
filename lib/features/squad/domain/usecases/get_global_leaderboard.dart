import 'package:injectable/injectable.dart';

import '../entities/leaderboard_entry.dart';
import '../repositories/squad_repository.dart';

@injectable
class GetGlobalLeaderboard {
  GetGlobalLeaderboard(this._repository);

  final SquadRepository _repository;

  /// [timeWindow] is `'all_time'`, `'weekly'`, or `'daily'`. [offset] is the
  /// number of rows to skip — a true server-side cursor (`p_offset`).
  Future<List<LeaderboardEntry>> call({
    required String timeWindow,
    int rowLimit = 50,
    int offset = 0,
  }) => _repository.fetchGlobalLeaderboard(
    timeWindow: timeWindow,
    rowLimit: rowLimit,
    offset: offset,
  );
}
