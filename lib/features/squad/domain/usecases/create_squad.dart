import 'package:injectable/injectable.dart';

import '../entities/squad.dart';
import '../repositories/squad_repository.dart';

@injectable
class CreateSquad {
  CreateSquad(this._repository);

  final SquadRepository _repository;

  Future<Squad> call(String name) => _repository.createSquad(name);
}
