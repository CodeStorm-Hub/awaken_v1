import 'package:injectable/injectable.dart';

import '../entities/territory.dart';
import '../repositories/territory_repository.dart';

@injectable
class WatchTerritories {
  WatchTerritories(this._repository);

  final TerritoryRepository _repository;

  Stream<List<Territory>> call() => _repository.watchTerritories();
}
