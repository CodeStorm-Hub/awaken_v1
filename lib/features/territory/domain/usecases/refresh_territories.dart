import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/territory_repository.dart';

@injectable
class RefreshTerritories implements UseCase<void, NoParams> {
  RefreshTerritories(this._repository);

  final TerritoryRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.refreshTerritories();
}
