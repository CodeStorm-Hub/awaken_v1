import 'package:injectable/injectable.dart';

import '../repositories/squad_repository.dart';

/// Caller's own rank within a specific squad (`my_squad_rank` RPC) — the
/// squad-scoped equivalent of [GetMyLeaderboardRank]'s global rank, backing
/// the weekly-reset ceremony when the caller is currently in a squad. Null
/// if the caller isn't rankable yet within that squad/window.
@injectable
class GetMySquadRank {
  GetMySquadRank(this._repository);

  final SquadRepository _repository;

  Future<int?> call({
    required String squadId,
    String timeWindow = 'all_time',
  }) {
    return _repository.fetchMySquadRank(
      squadId: squadId,
      timeWindow: timeWindow,
    );
  }
}
