import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/bounty_zone.dart';
import '../repositories/territory_repository.dart';

@injectable
class GetActiveBountyZones implements UseCase<List<BountyZone>, NoParams> {
  GetActiveBountyZones(this._repository);

  final TerritoryRepository _repository;

  @override
  Future<List<BountyZone>> call(NoParams params) =>
      _repository.fetchActiveBountyZones();
}
