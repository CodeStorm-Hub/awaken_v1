import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/squad_repository.dart';

@injectable
class LeaveSquad implements UseCase<void, NoParams> {
  LeaveSquad(this._repository);

  final SquadRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.leaveSquad();
}
