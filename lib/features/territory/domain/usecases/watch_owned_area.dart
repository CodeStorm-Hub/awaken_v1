import 'package:injectable/injectable.dart';

import '../repositories/territory_repository.dart';

@injectable
class WatchOwnedArea {
  WatchOwnedArea(this._repository);

  final TerritoryRepository _repository;

  Stream<double> call() => _repository.watchOwnedAreaSqm();
}
