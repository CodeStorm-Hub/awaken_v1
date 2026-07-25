import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/rival.dart';
import '../repositories/territory_repository.dart';

@injectable
class GetCurrentRival implements UseCase<Rival?, NoParams> {
  GetCurrentRival(this._repository);

  final TerritoryRepository _repository;

  @override
  Future<Rival?> call(NoParams params) => _repository.fetchCurrentRival();
}
