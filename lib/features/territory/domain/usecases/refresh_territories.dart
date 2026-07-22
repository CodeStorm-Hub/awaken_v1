import 'package:injectable/injectable.dart';

import '../entities/geo_bounds.dart';
import '../repositories/territory_repository.dart';

@injectable
class RefreshTerritories {
  RefreshTerritories(this._repository);

  final TerritoryRepository _repository;

  Future<void> call(GeoBounds bounds) => _repository.refreshTerritories(bounds);
}
