import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/territory_at_risk.dart';
import '../repositories/territory_repository.dart';

@injectable
class GetTerritoriesAtRisk implements UseCase<List<TerritoryAtRisk>, NoParams> {
  GetTerritoriesAtRisk(this._repository);

  final TerritoryRepository _repository;

  @override
  Future<List<TerritoryAtRisk>> call(NoParams params) =>
      _repository.fetchTerritoriesAtRisk();
}
