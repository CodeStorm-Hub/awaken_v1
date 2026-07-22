import 'package:injectable/injectable.dart';

import '../repositories/squad_repository.dart';

/// Composes `watchMySquad()` + `watchLeaderboard()` into a single "your
/// rank" stream for `HomePage`'s squad-rank stat tile — null when the user
/// has no squad (was previously a hardcoded `'#3'` mock).
@injectable
class WatchMyRank {
  WatchMyRank(this._repository);

  final SquadRepository _repository;

  Stream<int?> call() {
    return _repository.watchMySquad().asyncExpand((squad) {
      if (squad == null) return Stream.value(null);
      return _repository.watchLeaderboard(squad.id).map((entries) {
        final mine = entries.where((e) => e.isYou);
        return mine.isEmpty ? null : mine.first.rank;
      });
    });
  }
}
