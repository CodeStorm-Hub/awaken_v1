import 'package:injectable/injectable.dart';

import '../entities/territory_capture_feed_item.dart';
import '../repositories/squad_repository.dart';

/// "Conquest ticker" feed for the Squad page (2026-07-29 UI/UX audit item
/// 9) — recent captures across all users, most recent first.
@injectable
class GetRecentTerritoryCaptures {
  GetRecentTerritoryCaptures(this._repository);

  final SquadRepository _repository;

  Future<List<TerritoryCaptureFeedItem>> call({int rowLimit = 10}) =>
      _repository.fetchRecentTerritoryCaptures(rowLimit: rowLimit);
}
